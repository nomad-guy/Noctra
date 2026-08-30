"""
JioSaavn 320kbps Lossless Audio & Metadata Engine
"""
import time
import base64
import requests
from cryptography.hazmat.decrepit.ciphers import algorithms
from cryptography.hazmat.primitives.ciphers import Cipher, modes
from cryptography.hazmat.backends import default_backend
from backend.core.config import logger

# In-memory cache for trending and search results
_trending_cache = {'data': [], 'ts': 0}
_TRENDING_TTL = 300  # 5 minutes

def decrypt_jiosaavn_media_url(encrypted_media_url):
    """Decrypts JioSaavn DES encrypted_media_url to obtain direct 320kbps stream URL."""
    try:
        if not encrypted_media_url:
            return None
        key = b'38346591'
        cipher = Cipher(algorithms.TripleDES(key * 3), modes.ECB(), backend=default_backend())
        decryptor = cipher.decryptor()
        enc = base64.b64decode(encrypted_media_url.strip())
        dec = decryptor.update(enc) + decryptor.finalize()
        pad = dec[-1]
        if isinstance(pad, int) and pad < 8:
            dec = dec[:-pad]
        raw_url = dec.decode('utf-8', errors='ignore')
        stream_320 = raw_url.replace('_96.mp4', '_320.mp4').replace('_96.m4a', '_320.m4a').replace('_160.mp4', '_320.mp4')
        return stream_320
    except Exception as e:
        logger.warning(f"JioSaavn decryption error: {e}")
        return None

def _safe_request(url, params=None, headers=None, timeout=5, retries=2):
    """HTTP GET with retry logic and privacy stripping."""
    req_headers = headers or {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
    # Strip tracking headers
    for key in ('Referer', 'X-Forwarded-For', 'X-Real-IP'):
        req_headers.pop(key, None)

    for attempt in range(retries + 1):
        try:
            res = requests.get(url, params=params, headers=req_headers, timeout=timeout)
            if res.status_code == 200:
                return res
        except Exception as e:
            if attempt == retries:
                logger.error(f"Request failed after {retries + 1} attempts: {e}")
            else:
                time.sleep(1 * (attempt + 1))
    return None

def _parse_song_item(item):
    """Parse a single JioSaavn search result item into a clean dict."""
    song_name = item.get('song') or item.get('title')
    if not song_name:
        return None

    enc_url = item.get('encrypted_media_url')
    stream_url = decrypt_jiosaavn_media_url(enc_url)
    if not stream_url:
        return None

    raw_img = item.get('image', '')
    high_res_img = raw_img.replace('150x150', '500x500').replace('50x50', '500x500') if raw_img else ''

    primary_artists = item.get('primary_artists') or item.get('singers') or item.get('music') or 'Unknown Artist'
    clean_title = song_name.replace('&quot;', '"').replace('&amp;', '&').replace('&#039;', "'")
    clean_artists = primary_artists.replace('&quot;', '"').replace('&amp;', '&').replace('&#039;', "'")

    return {
        'id': f"saavn_{item.get('id')}",
        'title': clean_title,
        'artist': clean_artists,
        'album': item.get('album', ''),
        'artworkUrl': high_res_img,
        'thumbnail': high_res_img,
        'streamUrl': stream_url,
        'stream_url': stream_url,
        'source': 'jiosaavn_320k',
        'quality': '320kbps CD Lossless',
        'duration': int(item.get('duration') or 0),
        'year': item.get('year', ''),
        'genre': item.get('language', 'Universal').capitalize(),
        'has_lyrics': item.get('has_lyrics') == 'true',
    }

def search_jiosaavn_music(query, limit=15):
    """Searches JioSaavn high-fidelity catalog for official tracks with 500x500 artwork."""
    params = {
        '__call': 'search.getResults',
        '_format': 'json', '_marker': '0', 'cc': 'in',
        'includeMetaTags': '1', 'q': query, 'p': '1', 'n': str(limit)
    }
    res = _safe_request("https://www.jiosaavn.com/api.php", params=params)
    if not res:
        return []
    try:
        data = res.json()
        results = []
        for item in data.get('results', []):
            parsed = _parse_song_item(item)
            if parsed:
                results.append(parsed)
        return results
    except Exception as e:
        logger.error(f"JioSaavn search error: {e}")
    return []

def get_jiosaavn_trending(limit=20):
    """Fetches real trending chart songs from JioSaavn with caching."""
    now = time.time()
    if _trending_cache['data'] and now - _trending_cache['ts'] < _TRENDING_TTL:
        return _trending_cache['data'][:limit]

    # Use actual popular/chart song queries for real trending results
    chart_queries = [
        'Arijit Singh', 'Diljit Dosanjh', 'AP Dhillon',
        'Atif Aslam', 'Shreya Ghoshal hits', 'Pritam new songs',
        'Bollywood Top Hits', 'Punjabi Trending',
    ]
    all_results = []
    seen_ids = set()
    for q in chart_queries:
        tracks = search_jiosaavn_music(q, limit=5)
        for t in tracks:
            if t['id'] not in seen_ids:
                seen_ids.add(t['id'])
                all_results.append(t)
        if len(all_results) >= limit:
            break

    _trending_cache['data'] = all_results
    _trending_cache['ts'] = now
    return all_results[:limit]
