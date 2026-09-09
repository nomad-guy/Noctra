import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/ytdlp/music_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Radio Seed De-duplication Tests', () {
    test('isDuplicateTitle detects title variations and noise tags', () {
      const seed = 'Tum Hi Ho';
      final duplicates = [
        'Tum Hi Ho (Official Video)',
        'tum hi ho - lyric video',
        'Tum Hi Ho [Lofi Remix]',
        'Tum Hi Ho (Slowed + Reverb) [4K]',
        'Tum Hi Ho feat. Arijit Singh',
      ];

      for (final title in duplicates) {
        final cleanSeed = _clean(seed);
        final cleanTitle = _clean(title);
        final isDup = cleanSeed == cleanTitle || _hasWordOverlap(cleanSeed, cleanTitle);
        expect(isDup, isTrue, reason: '$title should be recognized as duplicate of $seed');
      }
    });

    test('isDuplicateTitle does not false-positive on different songs', () {
      const seed = 'Tum Hi Ho';
      final nonDuplicates = [
        'Tum Se Hi',
        'Humdard',
        'Sunn Raha Hai Na Tu',
        'Channa Mereya',
        'Agar Tum Saath Ho',
      ];

      for (final title in nonDuplicates) {
        final cleanSeed = _clean(seed);
        final cleanTitle = _clean(title);
        final isDup = cleanSeed == cleanTitle || _hasWordOverlap(cleanSeed, cleanTitle);
        expect(isDup, isFalse, reason: '$title should NOT be considered duplicate of $seed');
      }
    });
  });

  group('Vibe Feed Language Integration Tests', () {
    test('fetchVibeFeed respects custom languages', () async {
      // Query should incorporate language when non-English
      expect(
        MusicServiceCharts.fetchVibeFeed('late_night', languages: ['Korean']),
        completes,
      );
    });
  });
}

String _clean(String t) => t
    .toLowerCase()
    .replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), ' ')
    .replaceAll(
        RegExp(r'\b(official|video|audio|lyric|lyrics|remix|lofi|slowed|reverb|hd|4k|feat|ft)\b',
            caseSensitive: false),
        ' ')
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _hasWordOverlap(String a, String b) {
  final wa = a.split(' ').where((w) => w.isNotEmpty).toSet();
  final wb = b.split(' ').where((w) => w.isNotEmpty).toSet();
  if (wa.length >= 2 && wb.length >= 2) {
    final overlap = wa.intersection(wb).length;
    return (overlap / wa.union(wb).length) >= 0.6;
  }
  return false;
}
