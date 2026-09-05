import urllib.request
import json
import urllib.parse
import re

def sanitize(title):
    t = re.sub(r'\(.*?\)', '', title)
    t = re.sub(r'\[.*?\]', '', t)
    t = re.sub(r'\|.*', '', t)
    t = re.sub(r'feat\..*', '', t, flags=re.I)
    t = re.sub(r'ft\..*', '', t, flags=re.I)
    t = re.sub(r'official.*', '', t, flags=re.I)
    t = re.sub(r'video.*', '', t, flags=re.I)
    t = re.sub(r'audio.*', '', t, flags=re.I)
    return t.strip()

def has_devanagari(text):
    return any('\u0900' <= char <= '\u097f' for char in text)

def fetch_test(title, artist, prefer_hindi=False):
    clean_t = sanitize(title)
    split_a = re.split(r'[,&/]', artist)
    clean_a = split_a[0].strip() if split_a else artist
    print(f"\nSearching for [{clean_t}] by [{clean_a}] (prefer_hindi={prefer_hindi})...")
    
    # 1. LRCLIB search
    queries = [f"{clean_t} {clean_a}", clean_t]
    for q in queries:
        url = f"https://lrclib.net/api/search?q={urllib.parse.quote(q)}"
        req = urllib.request.Request(url, headers={'User-Agent': 'Noctra/1.0.4 (https://noctra.app)'})
        try:
            with urllib.request.urlopen(req, timeout=6) as res:
                items = json.loads(res.read().decode('utf-8'))
                if items:
                    if prefer_hindi:
                        # Prioritize item with Devanagari text
                        dev_items = [it for it in items if has_devanagari(it.get('syncedLyrics') or '') or has_devanagari(it.get('plainLyrics') or '')]
                        if dev_items:
                            chosen = dev_items[0]
                            print(f" -> Found DEVANAGARI HINDI lyrics on LRCLIB: {chosen.get('trackName')} (synced={bool(chosen.get('syncedLyrics'))})")
                            return True
                    # Otherwise take top synced or plain
                    synced_items = [it for it in items if it.get('syncedLyrics')]
                    if synced_items:
                        print(f" -> Found SYNCED lyrics on LRCLIB: {synced_items[0].get('trackName')}")
                        return True
                    if items[0].get('plainLyrics'):
                        print(f" -> Found PLAIN lyrics on LRCLIB: {items[0].get('trackName')}")
                        return True
        except Exception as e:
            print("LRCLIB err:", e)
    return False

if __name__ == '__main__':
    fetch_test('Kesariya (From "Brahmastra")', 'Pritam, Arijit Singh', prefer_hindi=True)
    fetch_test('Apna Bana Le', 'Arijit Singh, Sachin-Jigar', prefer_hindi=True)
    fetch_test('Tum Hi Ho (Official Video)', 'Arijit Singh', prefer_hindi=True)
    fetch_test('Channa Mereya', 'Arijit Singh', prefer_hindi=True)
    fetch_test('Jalebi Baby', 'Tesher', prefer_hindi=True)
    fetch_test('Starboy', 'The Weeknd', prefer_hindi=False)
