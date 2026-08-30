"""
YouTube Music & Multi-Source Audio Stream Extraction via yt-dlp
"""
import time
import re
import requests
import yt_dlp
from backend.core.config import logger, STREAM_CACHE, CACHE_TTL

def get_stream_url(video_id_or_query):
    """Extract authentic audio stream URL via yt-dlp android player client with query fallback."""
    clean_input = video_id_or_query.replace("yt_", "").replace("spot_", "").strip()
    video_id = None

    match = re.search(r'(?:v=|\/)([0-9A-Za-z_-]{11})', clean_input)
    if match:
        video_id = match.group(1)
    elif len(clean_input) == 11 and re.match(r'^[0-9A-Za-z_-]{11}$', clean_input):
        video_id = clean_input
    else:
        # Dynamic search resolution for song title/artist or Spotify tracks
        try:
            ydl_opts = {'format': 'ba/b', 'quiet': True, 'extract_flat': True, 'noplaylist': True}
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                res = ydl.extract_info(f"ytsearch1:{clean_input} audio", download=False)
                if res and 'entries' in res and res['entries']:
                    video_id = res['entries'][0].get('id')
        except Exception as e:
            logger.error(f"Search resolution error for {clean_input}: {e}")

    if not video_id:
        return None, {}

    now = time.time()
    if video_id in STREAM_CACHE:
        cached_url, headers, ts = STREAM_CACHE[video_id]
        if now - ts < CACHE_TTL:
            return cached_url, headers

    url = f"https://www.youtube.com/watch?v={video_id}"

    # Extract exact authentic audio stream via android player client
    ydl_opts = {
        'format': 'ba/b',
        'quiet': True,
        'no_warnings': True,
        'extract_flat': False,
        'skip_download': True,
        'noplaylist': True,
        'extractor_args': {'youtube': {'player_client': ['android']}}
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if info:
                stream_url = info.get('url')
                if not stream_url and 'formats' in info:
                    formats = [f for f in info['formats'] if f.get('vcodec') == 'none' and f.get('url')]
                    if formats:
                        formats.sort(key=lambda x: x.get('abr', 0) or 0, reverse=True)
                        stream_url = formats[0].get('url')

                headers = info.get('http_headers', {})
                if stream_url:
                    STREAM_CACHE[video_id] = (stream_url, headers, now)
                    return stream_url, headers
    except Exception as e:
        logger.error(f"Stream extraction error for {video_id}: {e}")

    return None, {}

def search_youtube_music(query, limit=10):
    """Searches YouTube Music via yt-dlp."""
    ydl_opts = {
        'format': 'bestaudio/best',
        'quiet': True,
        'no_warnings': True,
        'extract_flat': True,
        'noplaylist': True,
    }

    results = []
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            res = ydl.extract_info(f"ytsearch{limit}:{query}", download=False)
            if res and 'entries' in res:
                for entry in res['entries']:
                    if not entry:
                        continue
                    vid = entry.get('id')
                    thumbs = entry.get('thumbnails', [])
                    artwork = thumbs[-1].get('url') if thumbs else f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg"
                    stream_link = f"http://127.0.0.1:8088/api/stream/{vid}"
                    
                    results.append({
                        'id': f"yt_{vid}",
                        'title': entry.get('title', 'Unknown Title'),
                        'artist': entry.get('uploader', 'Unknown Artist'),
                        'artworkUrl': artwork,
                        'thumbnail': artwork,
                        'duration': entry.get('duration', 0),
                        'source': 'youtube',
                        'streamUrl': stream_link,
                        'stream_url': stream_link,
                    })
    except Exception as e:
        logger.error(f"YouTube search error: {e}")

    return results
