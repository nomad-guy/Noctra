import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/sources/noctra_local_database.dart';
import '../../../providers/app_providers.dart';
import '../../../main.dart';
import 'onboarding_artist_picker.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;
  final List<String> _selectedLanguages = ['Hindi', 'English'];
  final List<String> _selectedGenres = ['Bollywood', 'Lo-Fi', 'Synthwave'];
  final List<String> _selectedArtists = ['Arijit Singh', 'The Weeknd'];

  static const List<String> availableLanguages = [
    'Hindi', 'English', 'Punjabi', 'Urdu', 'Spanish', 'Korean', 'Japanese', 'Tamil', 'Telugu', 'French'
  ];

  static const List<String> availableGenres = [
    'Bollywood', 'Lo-Fi', 'Hip-Hop', 'Synthwave', 'Acoustic', 'Pop', 'EDM', 'Sufi', 'Rock', 'R&B', 'Phonk', 'Indie'
  ];

  void _finishOnboarding() async {
    final db = NoctraLocalDatabase();
    await db.completeOnboarding(
      languages: _selectedLanguages,
      genres: _selectedGenres,
      artists: _selectedArtists,
    );

    ref.read(musicRepositoryProvider).initOnboardingTaste(
      languages: _selectedLanguages,
      genres: _selectedGenres,
      artists: _selectedArtists,
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070709),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'NOCTRA',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.5,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  Text(
                    'Step ${_currentStep + 1} of 3',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _getStepTitle(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
              ),
              const SizedBox(height: 6),
              Text(
                _getStepSubtitle(),
                style: const TextStyle(fontSize: 13, color: Colors.white60),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _buildStepContent(),
              ),
              const SizedBox(height: 16),
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0: return 'What languages do you\nlisten to?';
      case 1: return 'Choose your favorite\nvibes & genres';
      default: return 'Pick 3 or more artists\nyou love';
    }
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case 0: return 'We will curate real-time lossless tracks in these languages.';
      case 1: return 'Shapes your 32-dimensional acoustic taste vector.';
      default: return 'Noctra AI trains its neural recommendation graph on these.';
    }
  }

  Widget _buildStepContent() {
    if (_currentStep == 0) {
      return Wrap(
        spacing: 10,
        runSpacing: 12,
        children: availableLanguages.map((lang) {
          final isSelected = _selectedLanguages.contains(lang);
          return _buildChoiceChip(lang, isSelected, () {
            setState(() {
              if (isSelected) {
                if (_selectedLanguages.length > 1) _selectedLanguages.remove(lang);
              } else {
                _selectedLanguages.add(lang);
              }
            });
          });
        }).toList(),
      );
    } else if (_currentStep == 1) {
      return Wrap(
        spacing: 10,
        runSpacing: 12,
        children: availableGenres.map((genre) {
          final isSelected = _selectedGenres.contains(genre);
          return _buildChoiceChip(genre, isSelected, () {
            setState(() {
              if (isSelected) {
                if (_selectedGenres.length > 1) _selectedGenres.remove(genre);
              } else {
                _selectedGenres.add(genre);
              }
            });
          });
        }).toList(),
      );
    } else {
      return OnboardingArtistPicker(
        selectedArtists: _selectedArtists,
        onToggle: (artist) {
          setState(() {
            if (_selectedArtists.contains(artist)) {
              if (_selectedArtists.length > 1) _selectedArtists.remove(artist);
            } else {
              _selectedArtists.add(artist);
            }
          });
        },
      );
    }
  }

  Widget _buildChoiceChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white12,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
            onPressed: () => setState(() => _currentStep--),
          )
        else
          const SizedBox(width: 48),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            elevation: 8,
          ),
          onPressed: () {
            if (_currentStep < 2) {
              setState(() => _currentStep++);
            } else {
              _finishOnboarding();
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentStep == 2 ? 'Start Listening' : 'Next',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}
