class TrustedAudioHosts {
  static const Set<String> hosts = {
    'aac.saavncdn.com',
    'saavncdn.com',
    'jiosaavn.com',
    'c.saavncdn.com',
    'www.jiosaavn.com',
    'storage.googleapis.com',
    'googlevideo.com',
    'ytimg.com',
    'i.ytimg.com',
    'lh3.googleusercontent.com',
    'akamaized.net',
    'cloudfront.net',
    'cdn.jsdelivr.net',
    'jamendo.com',
    'jamendocdn.com',
    'tidal.com',
    'tidalhifi.com',
    'sp-linear.tidal.com',
    'qobuz.com',
    'audio-qobuz.com',
    'hw-cdn.net',
    'fastly.net',
  };

  static bool isTrusted(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url.startsWith('/') ||
        url.startsWith('file:') ||
        url.startsWith('http://localhost') ||
        url.startsWith('http://127.0.0.1')) {
      return true;
    }
    try {
      final u = Uri.parse(url);
      if (u.scheme != 'https') return false;
      final h = u.host.toLowerCase();
      if (h.isEmpty) return false;
      if (hosts.contains(h)) return true;
      for (final allowed in hosts) {
        if (h.endsWith('.$allowed')) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
