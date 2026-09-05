"""
Noctra 16-Axis Keyword Scoring, Knowledge Graph, and Re-Ranker.

NOTE: This module does NOT contain a neural model or a vector store.
The "16-axis" representation is a deterministic keyword-driven
heuristic (see `generate_16axis_vector`) that produces a 16-d
fingerprint from text via substring matching and an MD5
perturbation. The "Hybrid Dense RAG" re-ranker combines a
prompt-side cosine similarity (60%) with a user-taste similarity
(40%); both similarities are computed on these keyword vectors, not
on learned embeddings. The previous module name implied ML that
does not exist on-device or in this process. The name is kept
publicly for backward compatibility with the API contract; do not
add features that rely on a real embedding model being present.
"""
import hashlib
import numpy as np

# 16 Acoustic Axes
AXIS_KEYS = [
    'dark_tone', 'ambient_depth', 'energy', 'chill_factor',
    'melancholy', 'acoustic_warmth', 'electronic', 'vocal_presence',
    'harmonic_density', 'analog_synth', 'night_drive', 'cognitive_focus',
    'uplift', 'sub_bass_weight', 'rhythm_tempo', 'instrumental'
]

# Knowledge Graph Relationship Nodes
KNOWLEDGE_GRAPH_NODES = {
    'synthwave': {'related_genres': ['retrowave', 'outrun', 'cyberpunk', 'dark electro'], 'mood': 'night_drive', 'energy_tier': 0.75},
    'lofi': {'related_genres': ['chillhop', 'ambient jazz', 'bedroom pop'], 'mood': 'chill_factor', 'energy_tier': 0.35},
    'bollywood': {'related_genres': ['filmi', 'sufi', 'romantic ballad', 'desi pop'], 'mood': 'acoustic_warmth', 'energy_tier': 0.65},
    'pop': {'related_genres': ['dance pop', 'synth pop', 'indie pop'], 'mood': 'uplift', 'energy_tier': 0.80},
    'classical': {'related_genres': ['neo-classical', 'orchestral', 'piano solo'], 'mood': 'cognitive_focus', 'energy_tier': 0.40},
    'electronic': {'related_genres': ['techno', 'house', 'trance', 'dnb'], 'mood': 'electronic', 'energy_tier': 0.90},
    'rock': {'related_genres': ['alternative', 'indie rock', 'post-rock', 'grunge'], 'mood': 'energy', 'energy_tier': 0.85},
    'hiphop': {'related_genres': ['trap', 'boom bap', 'conscious hip hop'], 'mood': 'sub_bass_weight', 'energy_tier': 0.78},
}

def generate_16axis_vector(text):
    """Generates a deterministic 16-axis coordinate vector in [0.0, 1.0]^16 for any query/song."""
    lower = text.lower()
    vec = [0.5] * 16

    # Keyword Semantic Alignments
    weights = {
        'dark': (0, 0.4), 'noir': (0, 0.45), 'night': (10, 0.4), 'midnight': (10, 0.45),
        'ambient': (1, 0.4), 'drone': (1, 0.45), 'space': (1, 0.35),
        'energy': (2, 0.4), 'hype': (2, 0.45), 'fast': (14, 0.4), 'dance': (2, 0.35),
        'chill': (3, 0.4), 'lofi': (3, 0.45), 'relax': (3, 0.4), 'calm': (3, 0.35),
        'sad': (4, 0.4), 'melancholy': (4, 0.45), 'heartbreak': (4, 0.4),
        'acoustic': (5, 0.45), 'piano': (5, 0.35), 'guitar': (5, 0.35), 'unplugged': (5, 0.4),
        'electronic': (6, 0.45), 'synth': (9, 0.45), 'synthwave': (9, 0.45), 'edm': (6, 0.4),
        'vocal': (7, 0.4), 'sing': (7, 0.35), 'choir': (7, 0.4),
        'harmonic': (8, 0.4), 'complex': (8, 0.35), 'orchestra': (8, 0.4),
        'drive': (10, 0.45), 'cruising': (10, 0.4),
        'focus': (11, 0.45), 'study': (11, 0.4), 'work': (11, 0.35),
        'happy': (12, 0.4), 'uplift': (12, 0.45), 'joy': (12, 0.4),
        'bass': (13, 0.45), 'sub': (13, 0.4), 'drop': (13, 0.35),
        'tempo': (14, 0.4), 'beat': (14, 0.35), 'rhythm': (14, 0.4),
        'instrumental': (15, 0.45), 'no vocals': (15, 0.5), 'score': (15, 0.4)
    }

    for word, (axis_idx, boost) in weights.items():
        if word in lower:
            vec[axis_idx] = min(1.0, vec[axis_idx] + boost)

    # Deterministic hash perturbation
    h_bytes = hashlib.md5(text.encode('utf-8')).digest()
    for i in range(16):
        byte_val = h_bytes[i % len(h_bytes)]
        perturbation = ((byte_val % 4) - 1.5) * 0.04
        vec[i] = max(0.05, min(0.95, vec[i] + perturbation))

    return vec

def cosine_similarity(v1, v2):
    """Computes cosine similarity between two 16-dimensional vectors with [0.0, 1.0] span."""
    if not v1 or not v2:
        return 0.5
    a = np.array(v1, dtype=float)[:16]
    b = np.array(v2, dtype=float)[:16]
    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)
    if norm_a == 0 or norm_b == 0:
        return 0.5
    return float(np.clip(np.dot(a, b) / (norm_a * norm_b), 0.0, 1.0))

def query_knowledge_graph_context(seed_text):
    """Traverses Knowledge Graph nodes to expand context and extract related subgenres and acoustic moods."""
    lower = seed_text.lower()
    expanded_nodes = []
    dominant_mood = 'universal'
    
    for genre, data in KNOWLEDGE_GRAPH_NODES.items():
        if genre in lower or any(sub in lower for sub in data['related_genres']):
            expanded_nodes.extend(data['related_genres'])
            dominant_mood = data['mood']

    return {
        'seed': seed_text,
        'expanded_clusters': list(set(expanded_nodes)),
        'dominant_mood': dominant_mood
    }

def hybrid_dense_rag_rerank(query, candidate_tracks, user_taste_vector=None):
    """Re-rank candidate tracks by keyword-vector similarity.

    Combines a prompt-side similarity (60%) with a user-taste
    similarity (40%) when a taste vector is supplied, otherwise
    uses the prompt similarity alone. Both similarities are cosine
    similarities on the deterministic 16-axis keyword vector; no
    learned embeddings are involved.
    """
    prompt_vector = generate_16axis_vector(query)
    ranked = []

    for track in candidate_tracks:
        track_text = f"{track.get('title', '')} {track.get('artist', '')} {track.get('genre', '')}"
        track_vector = generate_16axis_vector(track_text)
        
        prompt_sim = cosine_similarity(prompt_vector, track_vector)
        user_sim = cosine_similarity(user_taste_vector, track_vector) if user_taste_vector else prompt_sim

        # Hybrid composite score
        final_score = (0.60 * prompt_sim) + (0.40 * user_sim)
        track_copy = dict(track)
        track_copy['aiMatchScore'] = round(final_score * 100)
        track_copy['featureVector'] = track_vector
        ranked.append(track_copy)

    ranked.sort(key=lambda x: x['aiMatchScore'], reverse=True)
    return ranked
