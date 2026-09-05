/// Pinned YouTube InnerTube client definitions used for `/player` stream
/// resolution.
///
/// This is the "direct-URL path": both clients below return `OK` with
/// pre-signed audio `url` fields — no signature cipher, no n-transform, no
/// PO token — so a Dart resolver needs none of the JS decipher machinery.
///
/// Selection rationale (verified live Feb 2026; matches yt-dlp / YouTube.js
/// pins and Echo-Music's measured cascade):
/// * `ANDROID_TESTSUITE` was retired by YouTube in 2024 and answers
///   "This video is not available" for every video. It must never be used.
/// * Old `ANDROID_VR` builds (1.43.32, 1.61.48) are server-side version-gated
///   to `LOGIN_REQUIRED`. Only 1.65.10 still returns formats anonymously.
/// * `WEB` / `WEB_REMIX` / `TVHTML5` formats sit behind the signature cipher /
///   n-challenge and are not usable without a full decipher stack.
/// * `IOS` / `IPADOS` URLs are only ~1 MiB previews (403 past the cap).
class InnerTubeClientConfig {
  final String clientName;
  final String clientVersion;

  /// Sent as the `X-YouTube-Client-Name` header (YouTube uses the client id
  /// in that header, not the client name).
  final String clientId;
  final String userAgent;
  final Map<String, Object?> deviceFields;

  const InnerTubeClientConfig({
    required this.clientName,
    required this.clientVersion,
    required this.clientId,
    required this.userAgent,
    this.deviceFields = const {},
  });

  /// The `client` object embedded in the request `context`.
  Map<String, Object?> toContextClient([String? visitorData]) => {
        'clientName': clientName,
        'clientVersion': clientVersion,
        ...deviceFields,
        if (visitorData != null && visitorData.isNotEmpty)
          'visitorData': visitorData,
      };
}

class InnerTubeClientCatalog {
  InnerTubeClientCatalog._();

  /// The only client measured to serve a complete audio file and the first
  /// in the cascade. visionOS `0.1` is an internal YouTube client; it is
  /// expected to stop working at some point — ANDROID_VR is the durable pin.
  static const InnerTubeClientConfig visionOs = InnerTubeClientConfig(
    clientName: 'VISIONOS',
    clientVersion: '0.1',
    clientId: '101',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
        '(KHTML, like Gecko) Version/18.0 Safari/605.1.15',
    deviceFields: {
      'osName': 'visionOS',
      'osVersion': '1.3.21O771',
      'deviceMake': 'Apple',
      'deviceModel': 'RealityDevice14,1',
    },
  );

  /// Current yt-dlp / YouTube.js pin. Whole-file capable with direct URLs.
  /// Some networks gate it with `LOGIN_REQUIRED` unless a visitorData is
  /// supplied (header `X-Goog-Visitor-Id` + body context).
  static const InnerTubeClientConfig androidVr165 = InnerTubeClientConfig(
    clientName: 'ANDROID_VR',
    clientVersion: '1.65.10',
    clientId: '28',
    userAgent:
        'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android '
        '12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
    deviceFields: {
      'osName': 'Android',
      'osVersion': '12L',
      'deviceMake': 'Oculus',
      'deviceModel': 'Quest 3',
      'androidSdkVersion': 32,
    },
  );

  /// Ordered fallback cascade for stream resolution.
  static const List<InnerTubeClientConfig> streamClients = [
    visionOs,
    androidVr165,
  ];
}
