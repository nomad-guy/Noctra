"""
Spotify Dynamic Zero-Key Public Chart & Playlist Extractor
"""
import re
import json
import time
import requests
from backend.core.config import logger

_spotify_cache = {}
_CACHE_TTL = 900  # 15 minutes

SPOTIFY_CHARTS = {
    'top_hits': {'id': '37i9dQZF1DXcBWIGoYBM5M', 'name': "Today's Top Hits"},
    'global_50': {'id': '37i9dQZEVXbMDoHDwVN2tF', 'name': 'Top 50 - Global'},
    'viral_50': {'id': '37i9dQZF1DX2L0iB23Enbq', 'name': 'Viral Hits Global'},
    'pop_rising': {'id': '37i9dQZF1DWUa8ZRTfalHk', 'name': 'Pop Rising'},
    'rap_caviar': {'id': '37i9dQZF1DX0XUsuxWHRQd', 'name': 'RapCaviar'},
    'bollywood': {'id': '37i9dQZF1DX0XUfTFmZeM0', 'name': 'Bollywood Butter'},
    'chill_hits': {'id': '37i9dQZF1DX4WYpdgoIcn6', 'name': 'Chill Hits'},
}

def fetch_spotify_playlist(playlist_id, limit=20):
    """Fetches track list from Spotify's public embed page without API keys."""
    now = time.time()
    cache_key = f"{playlist_id}_{limit}"
    if cache_key in _spotify_cache and (now - _spotify_cache[cache_key]['ts']) < _CACHE_TTL:
        return _spotify_cache[cache_key]['tracks']

    url = f"https://open.spotify.com/embed/playlist/{playlist_id}"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }

    try:
        res = requests.get(url, headers=headers, timeout=8)
        if res.status_code != 200:
            return []

        match = re.search(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', res.text)
        if not match:
            return []

        data = json.loads(match.group(1))
        entity = data.get('props', {}).get('pageProps', {}).get('state', {}).get('data', {}).get('entity', {})
        tracklist = entity.get('trackList', [])

        cover_sources = entity.get('coverArt', {}).get('sources', [])
        default_art = cover_sources[0].get('url') if cover_sources else ''

        results = []
        for t in tracklist[:limit]:
            title = t.get('title', '').strip()
            artist = t.get('subtitle', '').strip()
            if not title:
                continue

            uri = t.get('uri', '')
            track_id = uri.split(':')[-1] if ':' in uri else t.get('uid', '')
            dur_sec = int((t.get('duration') or 180000) / 1000)

            results.append({
                'id': f"spot_{track_id}",
                'title': title,
                'artist': artist,
                'album': entity.get('title') or entity.get('name') or 'Spotify Chart',
                'artworkUrl': default_art,
                'thumbnail': default_art,
                'streamUrl': None,
                'source': 'spotify_chart',
                'quality': 'Dynamic 320k Master',
                'duration': dur_sec,
                'spotifyUri': uri,
            })

        _spotify_cache[cache_key] = {'tracks': results, 'ts': now}
        return results
    except Exception as e:
        logger.error(f"Spotify chart fetch error: {e}")
        return []

def get_dynamic_spotify_charts(chart_key='top_hits', limit=20):
    """Returns dynamic tracks for a chosen chart key."""
    chart_info = SPOTIFY_CHARTS.get(chart_key, SPOTIFY_CHARTS['top_hits'])
    return fetch_spotify_playlist(chart_info['id'], limit=limit)
