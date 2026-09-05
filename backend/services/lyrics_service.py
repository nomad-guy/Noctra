"""
Multi-Source Synchronized & Plain Lyrics Resolution Service
"""
import re
import requests
from backend.core.config import logger

def fetch_lyrics(title, artist_str, duration=0):
    """Fetches real synchronized or plain lyrics with duration-aware filtering."""
    if not title:
        return {"error": "Missing title"}

    clean_title = re.sub(r'\(.*?\)|\[.*?\]', '', title).strip()
    artists = [a.strip() for a in re.split(r'[,/&|]', artist_str) if a.strip()]

    # Parse duration to int for comparison
    try:
        song_duration = int(float(duration)) if duration else 0
    except (ValueError, TypeError):
        song_duration = 0

    # 1. LRCLIB exact get (most precise match)
    try:
        for artist_query in (artists[0] if artists else '', artist_str):
            if not artist_query:
                continue
            params = f'track_name={requests.utils.quote(clean_title)}&artist_name={requests.utils.quote(artist_query)}'
            if song_duration > 0:
                params += f'&duration={song_duration}'
            res = requests.get(
                f'https://lrclib.net/api/get?{params}',
                headers={'User-Agent': 'Noctra/1.0'},
                timeout=6
            )
            if res.status_code == 200:
                item = res.json()
                synced = item.get('syncedLyrics')
                plain = item.get('plainLyrics')
                if synced or plain:
                    return {
                        "found": True,
                        "synced": bool(synced),
                        "synced_lyrics": synced or "",
                        "plain_lyrics": plain or "",
                        "track_name": item.get('trackName', clean_title),
                        "artist_name": item.get('artistName', artist_str),
                    }
    except Exception as e:
        logger.error(f"LRCLIB exact get error: {e}")

    # 2. LRCLIB search with duration-aware filtering
    try:
        search_queries = [
            f"{clean_title} {artists[0]}" if artists else clean_title,
            clean_title,
            title,
        ]
        for q in search_queries:
            res = requests.get(
                f'https://lrclib.net/api/search?q={requests.utils.quote(q)}',
                headers={'User-Agent': 'Noctra/1.0'},
                timeout=6
            )
            if res.status_code != 200:
                continue
            items = res.json()
            if not isinstance(items, list) or len(items) == 0:
                continue

            # Filter candidates with synced lyrics
            synced_candidates = [i for i in items if i.get('syncedLyrics')]
            plain_candidates = [i for i in items if i.get('plainLyrics')]

            # Duration-aware selection: prefer entries within 15s of song duration
            best = _pick_best_match(synced_candidates, artists, song_duration)
            if best:
                return {
                    "found": True,
                    "synced": True,
                    "synced_lyrics": best.get('syncedLyrics', ''),
                    "plain_lyrics": best.get('plainLyrics', ''),
                    "track_name": best.get('trackName', clean_title),
                    "artist_name": best.get('artistName', artist_str),
                }

            # Fallback to plain lyrics with duration matching
            best_plain = _pick_best_match(plain_candidates, artists, song_duration)
            if best_plain:
                return {
                    "found": True,
                    "synced": False,
                    "synced_lyrics": "",
                    "plain_lyrics": best_plain.get('plainLyrics', ''),
                    "track_name": best_plain.get('trackName', clean_title),
                    "artist_name": best_plain.get('artistName', artist_str),
                }
    except Exception as e:
        logger.error(f"LRCLIB search error: {e}")

    # 3. JioSaavn Lyrics API Fallback (plain only)
    try:
        saavn_res = requests.get(
            f'https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&q={requests.utils.quote(clean_title)}&p=1&n=5',
            headers={'User-Agent': 'Mozilla/5.0'},
            timeout=5
        )
        if saavn_res.status_code == 200:
            data = saavn_res.json()
            for item in data.get('results', []):
                if item.get('has_lyrics') == 'true':
                    lyr_res = requests.get(
                        f'https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&lyrics_id={item.get("id")}&_format=json',
                        timeout=5
                    ).json()
                    plain_lyr = lyr_res.get('lyrics')
                    if plain_lyr:
                        clean_lyr = plain_lyr.replace('<br />', '\n').replace('<br>', '\n').replace('&quot;', '"')
                        return {
                            "found": True,
                            "synced": False,
                            "synced_lyrics": "",
                            "plain_lyrics": clean_lyr,
                            "track_name": item.get('song') or clean_title,
                            "artist_name": item.get('primary_artists') or artist_str,
                        }
    except Exception as e:
        logger.error(f"JioSaavn lyrics fallback error: {e}")

    return {
        "found": False,
        "synced": False,
        "synced_lyrics": "",
        "plain_lyrics": f"Lyrics currently unavailable for \"{clean_title}\".\nEnjoy the high-definition 320kbps CD soundscape.",
        "track_name": clean_title,
        "artist_name": artist_str,
    }


def _pick_best_match(candidates, artists, song_duration):
    """Pick the best lyrics candidate using artist matching + duration proximity."""
    if not candidates:
        return None

    # Score each candidate
    scored = []
    for item in candidates:
        score = 0
        item_artist = (item.get('artistName') or '').lower()

        # Artist match bonus
        for a in artists:
            if a.lower() in item_artist or item_artist in a.lower():
                score += 50
                break

        # Duration proximity bonus (within 15s = full bonus, degrades after)
        item_dur = item.get('duration') or 0
        if song_duration > 0 and item_dur > 0:
            diff = abs(song_duration - item_dur)
            if diff <= 15:
                score += 40
            elif diff <= 30:
                score += 20
            elif diff > 60:
                score -= 30  # Penalize large duration mismatches
        elif item_dur == 0:
            score += 5  # Unknown duration, slight neutral bonus

        scored.append((score, item))

    scored.sort(key=lambda x: x[0], reverse=True)
    if scored and scored[0][0] >= 0:
        return scored[0][1]
    return candidates[0]  # Absolute fallback
