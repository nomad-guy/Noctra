"""
Noctra Multi-Source Music Engine & AI Intelligence Sidecar
"""
import os
import sys
from flask import Flask, jsonify
from flask_cors import CORS

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.core.config import logger
from backend.routes.api_routes import api_bp

app = Flask(__name__)
CORS(app)

app.register_blueprint(api_bp, url_prefix='/api')

@app.route('/', methods=['GET'])
@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        "status": "online",
        "service": "Noctra Multi-Source Music & ML Engine",
        "version": "1.0.0",
        "ai_rag": "active",
        "endpoints": [
            "/api/search",
            "/api/trending",
            "/api/vibe_feed",
            "/api/lyrics",
            "/api/stream/<id>",
            "/api/proxy_stream",
            "/api/download"
        ]
    })

def run_server():
    logger.info("Starting Noctra Multi-Source & ML Engine on port 8088...")
    app.run(host='127.0.0.1', port=8088, threaded=True)

if __name__ == '__main__':
    run_server()
