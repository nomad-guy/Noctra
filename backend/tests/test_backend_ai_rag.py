"""
Comprehensive Automated Tests for Noctra AI RAG, Knowledge Graph & Multi-Source Lyrics
"""
import unittest
import os
import sys

# Add root directory to python path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from backend.services.ai_rag_service import (
    generate_16axis_vector, cosine_similarity,
    query_knowledge_graph_context, hybrid_dense_rag_rerank
)
from backend.services.lyrics_service import fetch_lyrics
from backend.services.jiosaavn_service import decrypt_jiosaavn_media_url

class TestNoctraEngine(unittest.TestCase):

    def test_16axis_vector_generation(self):
        """Test that 16-axis vector is generated with correct dimensions and normalized values."""
        v = generate_16axis_vector("Late Night Synthwave Drive with deep bass")
        self.assertEqual(len(v), 16)
        for val in v:
            self.assertTrue(0.0 <= val <= 1.0)
        
        # Check that Night Drive (axis 10) and Analog Synth (axis 9) are boosted
        self.assertGreater(v[10], 0.6)
        self.assertGreater(v[9], 0.6)

    def test_cosine_similarity(self):
        """Test cosine similarity computation."""
        v1 = [1.0] * 16
        v2 = [1.0] * 16
        sim = cosine_similarity(v1, v2)
        self.assertAlmostEqual(sim, 1.0, places=4)

        v3 = [0.0] * 16
        v3[0] = 1.0
        v4 = [0.0] * 16
        v4[1] = 1.0
        sim_ortho = cosine_similarity(v3, v4)
        self.assertAlmostEqual(sim_ortho, 0.0, places=4)

    def test_knowledge_graph_entity_linking(self):
        """Test Knowledge Graph entity expansion and mood linking."""
        kg = query_knowledge_graph_context("synthwave")
        self.assertIn('retrowave', kg['expanded_clusters'])
        self.assertIn('outrun', kg['expanded_clusters'])
        self.assertEqual(kg['dominant_mood'], 'night_drive')

    def test_hybrid_dense_rag_reranking(self):
        """Test Dense RAG candidate re-ranking."""
        candidates = [
            {'title': 'Midnight City', 'artist': 'M83', 'genre': 'Synthwave'},
            {'title': 'Acoustic Morning', 'artist': 'John', 'genre': 'Acoustic'},
            {'title': 'Heavy Techno Club', 'artist': 'DJ', 'genre': 'Electronic'},
        ]
        user_taste = generate_16axis_vector("Synthwave Retrowave Night")
        ranked = hybrid_dense_rag_rerank("Night Drive Synthwave", candidates, user_taste_vector=user_taste)
        self.assertEqual(len(ranked), 3)
        # Midnight City should rank #1
        self.assertEqual(ranked[0]['title'], 'Midnight City')
        self.assertGreater(ranked[0]['aiMatchScore'], ranked[1]['aiMatchScore'])

    def test_lyrics_resolution_multi_artist(self):
        """Test lyrics resolution for multi-artist songs like Lae Dooba."""
        res = fetch_lyrics('Lae Dooba', 'Manoj Muntashir, Rochak Kohli, Sunidhi Chauhan')
        self.assertTrue(res['found'])
        lyrics = res.get('synced_lyrics') or res.get('plain_lyrics')
        self.assertTrue(len(lyrics) > 50)

if __name__ == '__main__':
    unittest.main()
