"""
Main API Route Definitions for Noctra Backend Sidecar
"""
import os
from urllib.parse import urljoin, urlparse

import requests
from flask import (
    Blueprint,
    Response,
    jsonify,
    request,
    stream_with_context,
)
from backend.core.config import DEFAULT_DOWNLOAD_DIR, logger
from backend.services.ai_rag_service import (
    generate_16axis_vector,
    hybrid_dense_rag_rerank,
)
from backend.services.jiosaavn_service import (
    get_jiosaavn_trending,
    search_jiosaavn_music,
)
from backend.services.lyrics_service import fetch_lyrics
from backend.services.spotify_service import (
    SPOTIFY_CHARTS,
    get_dynamic_spotify_charts,
)
from backend.services.youtube_service import (
    get_stream_url,
    search_youtube_music,
)

api_bp = Blueprint('api', __name__)

_MAX_CATALOG_LIMIT = 50
_TRUSTED_STREAM_HOSTS = (
    'saavncdn.com',
    'jiosaavn.com',
    'googlevideo.com',
    'youtube.com',
    'ytimg.com',
    'jamendo.com',
)


def _bounded_limit(raw_value, default=15):
    try:
        return max(1, min(int(raw_value), _MAX_CATALOG_LIMIT))
    except (TypeError, ValueError):
        return default


def _is_trusted_stream_url(stream_url):
    try:
        parsed = urlparse(stream_url)
        if parsed.scheme != 'https' or not parsed.hostname:
            return False
        host = parsed.hostname.lower()
        return any(host == domain or host.endswith(f'.{domain}')
                   for domain in _TRUSTED_STREAM_HOSTS)
    except (TypeError, ValueError):
        return False


def _trusted_stream_get(stream_url, headers, timeout=15):
    """Fetch a stream while validating every redirect destination."""
    current_url = stream_url
    for _ in range(5):
        if not _is_trusted_stream_url(current_url):
            raise ValueError("Untrusted stream URL")
        response = requests.get(
            current_url,
            headers=headers,
            stream=True,
            timeout=timeout,
            allow_redirects=False)
        if not response.is_redirect:
            return response
        location = response.headers.get('Location')
        response.close()
        if not location:
            raise ValueError("Redirect missing Location header")
        current_url = urljoin(current_url, location)
    raise ValueError("Too many stream redirects")


@api_bp.route('/search', methods=['GET'])
def search_music():
    query = request.args.get('q', '').strip()
    source = request.args.get('source', 'all').lower().strip()
    limit = _bounded_limit(request.args.get('limit'), default=15)
    if not query:
        return jsonify({"results": []})
    if source in ('youtube', 'ytmusic', 'yt'):
        results = search_youtube_music(query, limit=limit)
    elif source in ('jiosaavn', 'saavn'):
        results = search_jiosaavn_music(query, limit=limit)
    else:
        results = search_jiosaavn_music(
            query, limit=limit) + search_youtube_music(query, limit=limit)
    ranked = hybrid_dense_rag_rerank(query, results)
    return jsonify(
        {"results": ranked[:limit], "query": query, "source": source})


@api_bp.route('/trending', methods=['GET'])
def get_trending():
    try:
        results = get_jiosaavn_trending(
            limit=_bounded_limit(request.args.get('limit'), default=20))
        return jsonify({"trending": results, "results": results})
    except Exception as e:
        logger.error(f"Trending error: {e}")
        return jsonify({"trending": [], "results": [], "error": str(e)})


@api_bp.route('/vibe_feed', methods=['GET'])
def get_vibe_feed():
    try:
        vibe = request.args.get('vibe', 'late_night').strip()
        limit = _bounded_limit(request.args.get('limit'), default=15)
        vibe_map = {
            'late_night': 'Arijit Singh midnight songs',
            'chill_lofi': 'lofi chill beats relaxing',
            'high_energy': 'Badshah party songs dance',
            'dark_synth': 'dark electronic ambient',
            'acoustic_warm': 'acoustic unplugged ballad',
            'bollywood': 'Bollywood latest romantic hits',
            'punjabi': 'Diljit Dosanjh AP Dhillon Punjabi',
            'rnb_soul': 'R&B soul smooth vibes',
            'classical': 'Indian classical instrumental',
            'kpop': 'K-Pop BTS trending',
            'sufi': 'Sufi Nusrat Fateh Ali Khan',
            'workout': 'workout motivation songs',
        }
        query = vibe_map.get(vibe, vibe.replace('_', ' '))
        candidates = search_jiosaavn_music(query, limit=limit * 2)
        ranked = hybrid_dense_rag_rerank(vibe, candidates)
        return jsonify({"results": ranked[:limit], "vibe": vibe})
    except Exception as e:
        logger.error(f"Vibe feed error: {e}")
        return jsonify({"results": [], "error": str(e)})


@api_bp.route('/ai_radio', methods=['GET'])
def ai_radio():
    """AI Radio: search for songs similar to a seed track by title+artist."""
    try:
        title = request.args.get('title', '').strip()
        artist = request.args.get('artist', '').strip()
        limit = _bounded_limit(request.args.get('limit'), default=15)
        if not title:
            return jsonify({"results": []})
        # Search by artist first (most relevant), then by title keywords
        queries = []
        if artist:
            queries.append(artist)
            queries.append(f"{artist} songs")
        queries.append(title)
        all_results = []
        seen_ids = set()
        for q in queries:
            tracks = search_jiosaavn_music(q, limit=8)
            for t in tracks:
                if t['id'] not in seen_ids:
                    seen_ids.add(t['id'])
                    all_results.append(t)
            if len(all_results) >= limit:
                break
        ranked = hybrid_dense_rag_rerank(title, all_results)
        return jsonify({"results": ranked[:limit]})
    except Exception as e:
        logger.error(f"AI Radio error: {e}")
        return jsonify({"results": [], "error": str(e)})


@api_bp.route('/vibe_curate', methods=['POST'])
def vibe_curate():
    data = request.get_json() or {}
    vibe = data.get('vibe', 'Late Night Drive')
    user_taste = data.get('userTasteVector')
    limit = _bounded_limit(data.get('limit'), default=12)

    candidates = search_jiosaavn_music(vibe, limit=limit * 2)
    ranked = hybrid_dense_rag_rerank(
        vibe, candidates, user_taste_vector=user_taste)
    return jsonify({"results": ranked[:limit], "vibe": vibe})


@api_bp.route('/spotify/charts', methods=['GET'])
def get_spotify_charts():
    """Returns dynamic Spotify public chart playlists without API keys."""
    try:
        chart_key = request.args.get('chart', 'top_hits').strip()
        limit = _bounded_limit(request.args.get('limit'), default=20)
        tracks = get_dynamic_spotify_charts(chart_key, limit=limit)
        return jsonify({
            "chart": chart_key,
            "charts_available": list(SPOTIFY_CHARTS.keys()),
            "results": tracks,
            "trending": tracks,
        })
    except Exception as e:
        logger.error(f"Spotify charts endpoint error: {e}")
        return jsonify({"results": [], "trending": [], "error": str(e)})


@api_bp.route('/spotify/oembed', methods=['GET'])
def spotify_oembed():
    """Zero-key Spotify oEmbed metadata proxy."""
    url = request.args.get('url', '').strip()
    if not url or not (url.startswith('https://open.spotify.com/')
                       or url.startswith('https://spotify.link/')):
        return jsonify({"error": "Invalid Spotify URL"}), 400
    try:
        res = requests.get(
            f"https://open.spotify.com/oembed?url={requests.utils.quote(url)}",
            timeout=5)
        if res.status_code == 200:
            return jsonify(res.json())
        return jsonify({"error": "Spotify oEmbed lookup failed"}
                       ), res.status_code
    except Exception as e:
        logger.error(f"Spotify oEmbed error: {e}")
        return jsonify({"error": "Spotify lookup error"}), 500


@api_bp.route('/metadata/enrich', methods=['GET'])
def enrich_metadata():
    """Zero-key MusicBrainz recording metadata enrichment."""
    title = request.args.get('title', '').strip()
    artist = request.args.get('artist', '').strip()
    if not title:
        return jsonify({"error": "Missing title"}), 400
    try:
        q = f"{title} {artist}".strip() if artist else title
        res = requests.get(
            "https://musicbrainz.org/ws/2/recording/",
            params={"query": q, "fmt": "json", "limit": 1},
            headers={"User-Agent": "NoctraApp/1.0.0 (contact@noctra.local)"},
            timeout=5
        )
        if res.status_code == 200:
            data = res.json()
            recs = data.get('recordings', [])
            if recs:
                rec = recs[0]
                releases = rec.get('releases', [])
                rel_mbid = releases[0].get('id') if releases else None
                return jsonify({
                    "found": True,
                    "mbid": rec.get('id'),
                    "title": rec.get('title'),
                    "album": releases[0].get('title') if releases else None,
                    "releaseMbid": rel_mbid,
                    "tags": [t.get('name') for t in rec.get('tags', [])],
                })
        return jsonify({"found": False})
    except Exception as e:
        logger.error(f"MusicBrainz enrichment error: {e}")
        return jsonify({"found": False, "error": str(e)})


def _stream_response(stream_url, headers):
    """Proxy audio bytes through Flask while preserving seek range requests."""
    if not _is_trusted_stream_url(stream_url):
        logger.warning("Rejected untrusted stream URL")
        return jsonify({"error": "Untrusted stream URL"}), 502

    # Proxy every stream so each redirect destination is validated before the
    # sidecar connects to it. Googlevideo URLs additionally need headers.
    try:
        req_headers = {}
        for key in (
            'User-Agent',
            'Accept',
            'Accept-Language',
            'Referer',
                'Cookie'):
            if key in headers:
                req_headers[key] = headers[key]
        if not req_headers.get('User-Agent'):
            req_headers['User-Agent'] = 'Mozilla/5.0'

        # Forward Range header from client for seeking support
        client_range = request.headers.get('Range')
        if client_range:
            req_headers['Range'] = client_range

        upstream = _trusted_stream_get(
            stream_url,
            headers=req_headers,
            timeout=15)

        # Cap the proxy response to a sane upper bound to prevent a
        # misbehaving upstream from pinning a worker thread.
        max_proxy_bytes = 500 * 1024 * 1024  # 500 MB
        upstream_content_length = upstream.headers.get('Content-Length')
        # Whether to advertise Content-Length at all. If the upstream
        # reports a size that is bigger than our proxy cap, we MUST
        # not pass that header through: the client would expect
        # `upstream_content_length` bytes, but the proxy will stop at
        # `max_proxy_bytes`, leaving a truncated body with a lying
        # Content-Length — the classic way browsers / just_audio
        # misbehave on audio streams. When the upstream size is
        # within our cap, we pass it through unchanged; otherwise
        # we omit it and let the client treat the response as
        # indeterminate-length chunked transfer.
        advertise_length = False
        if upstream_content_length:
            try:
                upstream_len_int = int(upstream_content_length)
                if upstream_len_int <= max_proxy_bytes:
                    advertise_length = True
                else:
                    logger.warning(
                        "Upstream Content-Length %s exceeds proxy cap; "
                        "omitting Content-Length header",
                        upstream_content_length)
            except (TypeError, ValueError):
                advertise_length = False

        def generate():
            nonlocal_max_bytes = max_proxy_bytes
            sent = 0
            for chunk in upstream.iter_content(chunk_size=1024 * 64):
                if chunk:
                    if sent + len(chunk) > nonlocal_max_bytes:
                        # Abort the upstream connection and stop the
                        # iterator. The client will see a truncated
                        # response; we deliberately avoid writing a
                        # JSON body here to keep the audio stream
                        # contract intact.
                        upstream.close()
                        return
                    sent += len(chunk)
                    yield chunk

        resp_headers = {
            'Content-Type': upstream.headers.get('Content-Type', 'audio/mp4'),
            'Accept-Ranges': 'bytes',
            'Access-Control-Allow-Origin': '*',
        }
        if advertise_length:
            resp_headers['Content-Length'] = upstream_content_length
        if upstream.headers.get('Content-Range'):
            resp_headers['Content-Range'] = upstream.headers['Content-Range']

        status_code = upstream.status_code  # 200 or 206 for range requests
        return Response(
            stream_with_context(generate()),
            status=status_code,
            headers=resp_headers,
        )
    except Exception as e:
        logger.error(f"Stream proxy error: {e}")
        return jsonify({"error": "Stream proxy failed"}), 502


@api_bp.route('/stream/<video_id>', methods=['GET'])
def stream_audio(video_id):
    stream_url, headers = get_stream_url(video_id)
    if not stream_url:
        return jsonify({"error": "Failed to resolve stream"}), 502
    return _stream_response(stream_url, headers)


@api_bp.route('/proxy_stream', methods=['GET'])
def proxy_stream():
    video_id = request.args.get('id', '').strip()
    query = request.args.get('q', '').strip()
    title = request.args.get('title', '').strip()
    artist = request.args.get('artist', '').strip()
    search_query = query or f"{title} {artist}".strip()
    if search_query:
        try:
            saavn_matches = search_jiosaavn_music(search_query, limit=2)
            if saavn_matches and saavn_matches[0].get('stream_url'):
                return _stream_response(saavn_matches[0]['stream_url'], {})
        except Exception as e:
            logger.error(f"JioSaavn proxy check error: {e}")
    lookup = search_query if search_query else video_id
    if not lookup:
        return jsonify({"error": "Missing lookup"}), 400
    stream_url, headers = get_stream_url(lookup)
    if not stream_url:
        return jsonify({"error": "Failed to resolve stream"}), 502
    return _stream_response(stream_url, headers)


@api_bp.route('/lyrics', methods=['GET'])
def get_lyrics():
    title = request.args.get('title', '').strip()
    artist = request.args.get('artist', '').strip()
    duration = request.args.get('duration', '0').strip()
    res = fetch_lyrics(title, artist, duration)
    return jsonify(res)


@api_bp.route('/ml/vectorize', methods=['POST'])
def vectorize_text():
    text = (request.get_json() or {}).get('text', '')
    return jsonify({'vector': generate_16axis_vector(text), 'dimensions': 16})


@api_bp.route('/download', methods=['POST'])
def download_song():
    data = request.get_json() or {}
    song_id, title, artist = data.get(
        'id', ''), data.get(
        'title', 'Unknown'), data.get(
            'artist', 'Unknown')
    stream_url = None
    if song_id:
        stream_url, _ = get_stream_url(song_id)
    if not stream_url or not _is_trusted_stream_url(stream_url):
        return jsonify(
            {"error": "Unable to resolve a trusted stream URL"}), 400
    try:
        c_title = "".join(
            c for c in title if c.isalnum() or c in (
                ' ', '_', '-')).strip()
        c_artist = "".join(
            c for c in artist if c.isalnum() or c in (
                ' ', '_', '-')).strip()
        # Collision-safe filename: include a short hash of the song
        # id so two different songs with the same title/artist no
        # longer overwrite each other. Also normalise length so the
        # final path stays within POSIX limits.
        import hashlib
        id_hash = hashlib.sha256(song_id.encode('utf-8')).hexdigest()[:10]
        base = f"{(c_artist or 'Unknown')[:32]} - {(c_title or 'track')[:48]}"
        filepath = os.path.join(
            DEFAULT_DOWNLOAD_DIR,
            f"{base} [{id_hash}].m4a")
        # Hard cap on a single download response to prevent disk
        # exhaustion from a misbehaving upstream.
        max_bytes = 200 * 1024 * 1024  # 200 MB
        if not os.path.exists(filepath):
            resp = requests.get(
                stream_url,
                stream=True,
                timeout=30,
                allow_redirects=False)
            if resp.status_code == 200:
                # Write to a temp sibling and atomically rename so a
                # partial download never leaves a corrupt .m4a behind.
                tmp_path = filepath + '.part'
                with open(tmp_path, 'wb') as f:
                    received = 0
                    for chunk in resp.iter_content(
                            chunk_size=1024 * 64):
                        if chunk:
                            f.write(chunk)
                            received += len(chunk)
                            if received > max_bytes:
                                f.close()
                                os.remove(tmp_path)
                                return jsonify(
                                    {
                                        "error":
                                            "Download exceeded size limit"
                                    }), 413
                os.replace(tmp_path, filepath)
            else:
                return jsonify(
                    {
                        "error":
                            f"Download failed, status {resp.status_code}"
                    }), 502
        # Do not leak the absolute server filesystem path to the
        # client â€" the client only needs to know the download
        # succeeded and how to identify the file.
        return jsonify({
            "status": "success",
            "message": "Downloaded lossless track",
            "filename": os.path.basename(filepath),
        })
    except Exception as e:
        logger.error(f"Download error: {e}")
        return jsonify({"error": str(e)}), 500
