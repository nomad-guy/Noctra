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
  };

  static bool isTrusted(String? url) {
    if (url == null || url.isEmpty) return false;
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
