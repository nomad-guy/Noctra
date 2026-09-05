"""
Automated tests for the Noctra AI RAG, knowledge graph, and lyrics services.
"""
import unittest
from unittest.mock import Mock, patch

from backend.routes.api_routes import (
    _bounded_limit,
    _is_trusted_stream_url,
    _trusted_stream_get,
)
from backend.services.ai_rag_service import (
    cosine_similarity,
    generate_16axis_vector,
    hybrid_dense_rag_rerank,
    query_knowledge_graph_context,
)
from backend.services.lyrics_service import fetch_lyrics


class TestNoctraEngine(unittest.TestCase):

    def test_api_limits_are_bounded(self):
        self.assertEqual(_bounded_limit('999'), 50)
        self.assertEqual(_bounded_limit('-2'), 1)
        self.assertEqual(_bounded_limit('invalid', default=12), 12)

    def test_stream_urls_require_trusted_https_hosts(self):
        self.assertTrue(_is_trusted_stream_url(
            'https://r1---sn.googlevideo.com/audio'))
        self.assertTrue(_is_trusted_stream_url(
            'https://aac.saavncdn.com/audio'))
        self.assertFalse(_is_trusted_stream_url(
            'http://aac.saavncdn.com/audio'))
        self.assertFalse(_is_trusted_stream_url('https://127.0.0.1/admin'))

    def test_stream_proxy_rejects_untrusted_redirect_destination(self):
        redirect_response = Mock()
        redirect_response.is_redirect = True
        redirect_response.headers = {'Location': 'http://127.0.0.1/admin'}

        with patch(
                'backend.routes.api_routes.requests.get',
                return_value=redirect_response) as get:
            with self.assertRaises(ValueError):
                _trusted_stream_get(
                    'https://r1---sn.googlevideo.com/audio', {}, timeout=1)

        get.assert_called_once()
        redirect_response.close.assert_called_once()

    def test_16axis_vector_generation(self):
        """The generated 16-axis vector has normalized values."""
        v = generate_16axis_vector("Late Night Synthwave Drive with deep bass")
        self.assertEqual(len(v), 16)
        for val in v:
            self.assertTrue(0.0 <= val <= 1.0)

        # Check that Night Drive (axis 10) and Analog Synth (axis 9) are
        # boosted
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
            {'title': 'Midnight City',
             'artist': 'M83', 'genre': 'Synthwave'},
            {'title': 'Acoustic Morning',
             'artist': 'John', 'genre': 'Acoustic'},
            {'title': 'Heavy Techno Club',
             'artist': 'DJ', 'genre': 'Electronic'},
        ]
        user_taste = generate_16axis_vector("Synthwave Retrowave Night")
        ranked = hybrid_dense_rag_rerank(
            "Night Drive Synthwave",
            candidates,
            user_taste_vector=user_taste,
        )
        self.assertEqual(len(ranked), 3)
        # Midnight City should rank #1
        self.assertEqual(ranked[0]['title'], 'Midnight City')
        self.assertGreater(
            ranked[0]['aiMatchScore'],
            ranked[1]['aiMatchScore'])

    def test_lyrics_resolution_multi_artist(self):
        """Test lyrics resolution for multi-artist songs like Lae Dooba."""
        res = fetch_lyrics(
            'Lae Dooba',
            'Manoj Muntashir, Rochak Kohli, Sunidhi Chauhan')
        self.assertTrue(res['found'])
        lyrics = res.get('synced_lyrics') or res.get('plain_lyrics')
        self.assertTrue(len(lyrics) > 50)


if __name__ == '__main__':
    unittest.main()
