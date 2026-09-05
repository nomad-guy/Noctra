import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';

/// Interactive modal sheet allowing users to tune their music languages & genres.
class MusicPreferencesSheet extends StatefulWidget {
  final bool isDark;
  final WidgetRef ref;

  const MusicPreferencesSheet({
    super.key,
    required this.isDark,
    required this.ref,
  });

  static const List<String> availableLanguages = [
    'Hindi', 'English', 'Punjabi', 'Urdu', 'Spanish', 'Korean',
    'Japanese', 'Tamil', 'Telugu', 'French', 'Marathi', 'Bengali',
  ];

  static const List<String> availableGenres = [
    'Bollywood', 'Lo-Fi', 'Hip-Hop', 'Synthwave', 'Acoustic', 'Pop',
    'EDM', 'Sufi', 'Rock', 'R&B', 'Phonk', 'Indie',
  ];

  static void show(BuildContext context, WidgetRef ref, bool isDark) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MusicPreferencesSheet(isDark: isDark, ref: ref),
    );
  }

  @override
  State<MusicPreferencesSheet> createState() => _MusicPreferencesSheetState();
}

class _MusicPreferencesSheetState extends State<MusicPreferencesSheet> {
  late final List<String> _selectedLangs;
  late final List<String> _selectedGenres;

  @override
  void initState() {
    super.initState();
    final repo = widget.ref.read(musicRepositoryProvider);
    _selectedLangs = List<String>.from(
      repo.onboardedLanguages.isNotEmpty ? repo.onboardedLanguages : ['English'],
    );
    _selectedGenres = List<String>.from(
      repo.onboardedGenres.isNotEmpty ? repo.onboardedGenres : ['Pop'],
    );
  }

  void _toggleItem(List<String> list, String item) {
    HapticFeedback.selectionClick();
    setState(() {
      if (list.contains(item)) {
        if (list.length > 1) list.remove(item);
      } else {
        list.add(item);
      }
    });
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    final repo = widget.ref.read(musicRepositoryProvider);
    await repo.completeOnboarding(
      languages: _selectedLangs,
      genres: _selectedGenres,
      artists: repo.onboardedArtists,
    );
    repo.initOnboardingTaste(
      languages: _selectedLangs,
      genres: _selectedGenres,
      artists: repo.onboardedArtists,
    );
    await refreshHomeFeeds(widget.ref);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tune Music Taste',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: isDark ? Colors.white70 : Colors.black54),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PREFERRED LANGUAGES',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: MusicPreferencesSheet.availableLanguages.map((l) {
                      final sel = _selectedLangs.contains(l);
                      return FilterChip(
                        label: Text(l),
                        selected: sel,
                        onSelected: (_) => _toggleItem(_selectedLangs, l),
                        backgroundColor: isDark ? const Color(0xFF202022) : const Color(0xFFEEEEEE),
                        selectedColor: isDark ? Colors.white : Colors.black,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: sel ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'FAVORITE GENRES',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: MusicPreferencesSheet.availableGenres.map((g) {
                      final sel = _selectedGenres.contains(g);
                      return FilterChip(
                        label: Text(g),
                        selected: sel,
                        onSelected: (_) => _toggleItem(_selectedGenres, g),
                        backgroundColor: isDark ? const Color(0xFF202022) : const Color(0xFFEEEEEE),
                        selectedColor: isDark ? Colors.white : Colors.black,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: sel ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _save,
              child: const Text('Apply Taste Preferences', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
