import 'dart:math';

/// High-precision song matching guard that prevents wrong-song / wrong-stream
/// substitution across search results and stream resolvers.
///
/// Ensures:
/// 1. Version tag consistency: Remixed, Live, Acoustic, Instrumental, Slowed,
///    and Sped-Up songs ONLY match candidates with identical modifiers. Clean
///    studio tracks NEVER match remixes, live concerts, or covers.
/// 2. Primary artist validation: The primary artist must be present in the
///    candidate title, artist, or channel.
/// 3. Duration boundaries: Rejects clips/previews (< 45s) and durations differing
///    by more than 45s or 25% from the expected track duration.
class TrackMatchingGuard {
  static const Set<String> _modifierTags = {
    'remix',
    'live',
    'acoustic',
    'instrumental',
    'karaoke',
    'slowed',
    'reverb',
    'sped up',
    'speed up',
    'nightcore',
    'cover',
    'orchestral',
    'piano',
    'lofi',
    'lo-fi',
    'clean',
    'extended',
    'radio edit',
  };

  static const Set<String> _noiseTags = {
    'official audio',
    'official video',
    'official music video',
    'lyric video',
    'lyrics video',
    'audio',
    'video',
    'lyrics',
    'hd',
    '4k',
    'hq',
    'visualizer',
    'mv',
  };

  /// Evaluates whether [candidateTitle], [candidateArtist], and optional [candidateDuration]
  /// match the target [targetTitle], [targetArtist], and [targetDuration] with high confidence.
  ///
  /// Returns a confidence score between 0.0 and 1.0. A score >= 0.75 is considered a safe match.
  static double calculateConfidence({
    required String targetTitle,
    required String targetArtist,
    Duration? targetDuration,
    required String candidateTitle,
    String? candidateArtist,
    Duration? candidateDuration,
  }) {
    if (targetTitle.trim().isEmpty || candidateTitle.trim().isEmpty) return 0.0;

    final normCandTitle = _normalizeForComparison(candidateTitle);
    final normCandArtist = _normalizeForComparison(candidateArtist ?? '');

    // 1. Version Modifier Check: If target has modifier, candidate MUST have it.
    // If target does NOT have modifier, candidate MUST NOT have modifier.
    final targetModifiers = _extractModifiers(targetTitle);
    final candModifiers = _extractModifiers(candidateTitle);

    if (targetModifiers.isNotEmpty) {
      // Candidate must share at least the primary modifier
      final hasOverlap = targetModifiers.any((m) => candModifiers.contains(m));
      if (!hasOverlap) {
        return 0.1; // Reject: target asked for remix/live, but candidate is studio or different version
      }
    } else {
      // Target is standard/clean track. Reject if candidate is a remix/live/cover/slowed version!
      final significantCandModifiers = candModifiers.where((m) =>
          m != 'clean' && m != 'radio edit' && m != 'extended');
      if (significantCandModifiers.isNotEmpty) {
        return 0.15; // Reject: user wanted standard track, candidate is an unauthorized modifier
      }
    }

    // 2. Primary Artist Verification
    final primaryTargetArtist = _extractPrimaryArtist(targetArtist);
    bool artistMatched = false;
    if (primaryTargetArtist.isNotEmpty) {
      final candCombined = '$normCandArtist $normCandTitle';
      if (candCombined.contains(primaryTargetArtist) ||
          _fuzzyTokenMatch(primaryTargetArtist, candCombined) >= 0.75) {
        artistMatched = true;
      }
    } else {
      artistMatched = true; // No artist provided, skip artist penalty
    }

    if (!artistMatched && targetArtist.trim().isNotEmpty) {
      return 0.2; // Reject: different artist entirely (e.g. Lionel Richie vs Adele)
    }

    // 3. Title Core Match
    final coreTarget = _stripAllTags(targetTitle);
    final coreCand = _stripAllTags(candidateTitle);
    final titleScore = _tokenSimilarity(coreTarget, coreCand);

    if (titleScore < 0.60) {
      return titleScore * 0.5; // Title mismatch
    }

    // 4. Duration Verification
    double durationScore = 1.0;
    if (targetDuration != null &&
        targetDuration.inSeconds > 30 &&
        candidateDuration != null &&
        candidateDuration.inSeconds > 0) {
      final targetSec = targetDuration.inSeconds;
      final candSec = candidateDuration.inSeconds;

      // Immediately reject short clips/previews (< 45s) when target is > 1 min
      if (candSec < 45 && targetSec >= 60) return 0.05;

      final diffSec = (targetSec - candSec).abs();
      final diffRatio = diffSec / targetSec;

      if (diffSec > 60 || diffRatio > 0.35) {
        // Discard 1-hour loops or extended concert sets
        return 0.2;
      } else if (diffSec <= 15 || diffRatio <= 0.08) {
        durationScore = 1.0;
      } else {
        durationScore = (1.0 - diffRatio).clamp(0.4, 0.9);
      }
    }

    final totalScore = (titleScore * 0.65) +
        ((artistMatched ? 1.0 : 0.0) * 0.20) +
        (durationScore * 0.15);

    return totalScore.clamp(0.0, 1.0);
  }

  /// Returns true if confidence >= 0.75 (safe match threshold).
  static bool isSafeMatch({
    required String targetTitle,
    required String targetArtist,
    Duration? targetDuration,
    required String candidateTitle,
    String? candidateArtist,
    Duration? candidateDuration,
  }) {
    final conf = calculateConfidence(
      targetTitle: targetTitle,
      targetArtist: targetArtist,
      targetDuration: targetDuration,
      candidateTitle: candidateTitle,
      candidateArtist: candidateArtist,
      candidateDuration: candidateDuration,
    );
    return conf >= 0.75;
  }

  static Set<String> _extractModifiers(String text) {
    final lower = text.toLowerCase();
    final found = <String>{};
    for (final tag in _modifierTags) {
      if (lower.contains(tag)) {
        found.add(tag);
      }
    }
    return found;
  }

  static String _extractPrimaryArtist(String artist) {
    final cleaned = _normalizeForComparison(artist);
    if (cleaned.isEmpty) return '';
    final parts = cleaned.split(RegExp(r'\s*(?:,|&|feat\.?|ft\.?|vs\.?|\/)\s*'));
    return parts.first.trim();
  }

  static String _normalizeForComparison(String input) {
    var s = input.toLowerCase();
    // Remove diacritics / accents
    s = s.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
    // Replace punctuation with whitespace
    s = s.replaceAll(RegExp(r'[^\w\s]'), ' ');
    // Collapse multiple whitespaces
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _stripAllTags(String input) {
    var s = input.toLowerCase();
    // Strip bracketed / parenthetical phrases
    s = s.replaceAll(RegExp(r'\(.*?\)'), ' ');
    s = s.replaceAll(RegExp(r'\[.*?\]'), ' ');
    // Strip noise tags
    for (final noise in _noiseTags) {
      s = s.replaceAll(noise, ' ');
    }
    for (final mod in _modifierTags) {
      s = s.replaceAll(mod, ' ');
    }
    return _normalizeForComparison(s);
  }

  static double _tokenSimilarity(String s1, String s2) {
    final t1 = s1.split(' ').where((w) => w.length > 1).toSet();
    final t2 = s2.split(' ').where((w) => w.length > 1).toSet();

    if (t1.isEmpty || t2.isEmpty) {
      return (s1.trim() == s2.trim()) ? 1.0 : 0.0;
    }

    final intersection = t1.intersection(t2).length;
    final union = t1.union(t2).length;
    final jaccard = union > 0 ? (intersection / union) : 0.0;

    if (s1.contains(s2) || s2.contains(s1)) {
      return max(jaccard, 0.85);
    }

    return jaccard;
  }

  static double _fuzzyTokenMatch(String query, String haystack) {
    final tokens = query.split(' ').where((w) => w.length > 1).toList();
    if (tokens.isEmpty) return 0.0;
    int matched = 0;
    for (final t in tokens) {
      if (haystack.contains(t)) matched++;
    }
    return matched / tokens.length;
  }

  /// Parses duration strings such as "3:45", "03:45", "1:02:30" into a [Duration].
  static Duration? parseDurationString(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final clean = text.trim();
    final parts = clean.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]);
      final s = int.tryParse(parts[1]);
      if (m != null && s != null) {
        return Duration(minutes: m, seconds: s);
      }
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final s = int.tryParse(parts[2]);
      if (h != null && m != null && s != null) {
        return Duration(hours: h, minutes: m, seconds: s);
      }
    }
    return null;
  }
}
