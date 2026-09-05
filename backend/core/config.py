"""
Noctra Backend Configuration & Constants
"""
import os
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("NoctraBackend")

DEFAULT_DOWNLOAD_DIR = os.path.expanduser("~/Music/Noctra")
os.makedirs(DEFAULT_DOWNLOAD_DIR, exist_ok=True)

# In-memory stream URL cache to avoid redundant extractions
STREAM_CACHE = {}  # { yt_id: (stream_url, req_headers, timestamp) }
CACHE_TTL = 3600  # 1 hour
