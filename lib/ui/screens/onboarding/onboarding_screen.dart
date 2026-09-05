import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import 'onboarding_artist_picker.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;
  final List<String> _selectedLanguages = [];
  final List<String> _selectedGenres = [];
  final List<String> _selectedArtists = [];

  bool get _canProceed {
    if (_currentStep == 0) return _selectedLanguages.isNotEmpty;
    if (_currentStep == 1) return _selectedGenres.isNotEmpty;
    return _selectedArtists.isNotEmpty;
  }

  final List<String> _displayedLanguages = [
    'Hindi', 'English', 'Punjabi', 'Urdu', 'Spanish', 'Korean', 'Japanese', 'Tamil', 'Telugu', 'French'
  ];

  final List<String> _displayedGenres = [
    'Bollywood', 'Lo-Fi', 'Hip-Hop', 'Synthwave', 'Acoustic', 'Pop', 'EDM', 'Sufi', 'Rock', 'R&B', 'Phonk', 'Indie'
  ];

  static const Map<String, List<String>> _relatedLanguages = {
    'Hindi': ['Urdu', 'Punjabi', 'Bhojpuri', 'Marathi', 'Gujarati', 'Bengali'],
    'English': ['Spanish', 'French', 'German', 'Italian', 'Portuguese'],
    'Punjabi': ['Hindi', 'Urdu', 'Haryanvi'],
    'Urdu': ['Hindi', 'Punjabi', 'Arabic', 'Persian'],
    'Spanish': ['Portuguese', 'Italian', 'French'],
    'Korean': ['Japanese', 'Mandarin', 'Thai'],
    'Japanese': ['Korean', 'Mandarin'],
    'Tamil': ['Telugu', 'Malayalam', 'Kannada'],
    'Telugu': ['Tamil', 'Kannada', 'Malayalam'],
    'French': ['Spanish', 'Italian', 'German'],
  };

  static const Map<String, List<String>> _relatedGenres = {
    'Bollywood': ['Sufi', 'Ghazal', 'Filmi', 'Desi Pop', 'Qawwali'],
    'Lo-Fi': ['Chillhop', 'Ambient', 'Downtempo', 'Bedroom Pop'],
    'Hip-Hop': ['Desi Hip-Hop', 'Trap', 'Boom Bap', 'Drill', 'Cloud Rap'],
    'Synthwave': ['Retrowave', 'Cyberpunk', 'Darksynth', 'Vaporwave', 'City Pop'],
    'Acoustic': ['Folk', 'Indie Acoustic', 'Singer-Songwriter', 'Unplugged'],
    'Pop': ['Desi Pop', 'Dance Pop', 'Synth-Pop', 'K-Pop', 'Electropop'],
    'EDM': ['House', 'Future Bass', 'Techno', 'Trance', 'Dubstep'],
    'Sufi': ['Qawwali', 'Ghazal', 'Sufi Rock', 'Mystic'],
    'Rock': ['Alt Rock', 'Indie Rock', 'Hard Rock', 'Grunge'],
    'R&B': ['Neo-Soul', 'Contemporary R&B', 'Trap Soul'],
    'Phonk': ['Drift Phonk', 'Wave Phonk', 'Memphis Rap'],
    'Indie': ['Indie Pop', 'Indie Rock', 'Dream Pop', 'Shoegaze'],
  };

  void _finishOnboarding() async {
    final repo = ref.read(musicRepositoryProvider);
    final effectiveLanguages = _selectedLanguages.isNotEmpty ? _selectedLanguages : ['English'];
    final effectiveGenres = _selectedGenres.isNotEmpty ? _selectedGenres : ['Pop'];
    final effectiveArtists = _selectedArtists.isNotEmpty ? _selectedArtists : ['The Weeknd'];

    await repo.completeOnboarding(
      languages: effectiveLanguages,
      genres: effectiveGenres,
      artists: effectiveArtists,
    );

    repo.initOnboardingTaste(
      languages: effectiveLanguages,
      genres: effectiveGenres,
      artists: effectiveArtists,
    );

    ref.read(onboardingCompletedProvider.notifier).state = true;
  }

  void _handleLanguageTapped(String lang) {
    setState(() {
      if (_selectedLanguages.contains(lang)) {
        if (_selectedLanguages.length > 1) _selectedLanguages.remove(lang);
      } else {
        _selectedLanguages.add(lang);
        final related = _relatedLanguages[lang];
        if (related != null) {
          for (final rel in related) {
            if (!_displayedLanguages.contains(rel) && _displayedLanguages.length < 24) {
              _displayedLanguages.add(rel);
            }
          }
        }
      }
    });
  }

  void _handleGenreTapped(String genre) {
    setState(() {
      if (_selectedGenres.contains(genre)) {
        if (_selectedGenres.length > 1) _selectedGenres.remove(genre);
      } else {
        _selectedGenres.add(genre);
        final related = _relatedGenres[genre];
        if (related != null) {
          for (final rel in related) {
            if (!_displayedGenres.contains(rel) && _displayedGenres.length < 36) {
              _displayedGenres.add(rel);
            }
          }
        }
      }
    });
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
                  Text('NOCTRA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 3.5, color: Colors.white.withValues(alpha: 0.9))),
                  Text('Step ${_currentStep + 1} of 3', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54)),
                ],
              ),
              const SizedBox(height: 20),
              Text(_getStepTitle(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
              const SizedBox(height: 6),
              Text(_getStepSubtitle(), style: const TextStyle(fontSize: 13, color: Colors.white60)),
              const SizedBox(height: 20),
              Expanded(child: _buildStepContent()),
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
      case 0: return 'Curates real-time high-fidelity tracks in these languages.';
      case 1: return 'Shapes your 32-dimensional neural taste vector.';
      default: return 'Explore dynamically. Tapping artists discovers similar musicians.';
    }
  }

  Widget _buildStepContent() {
    if (_currentStep == 0) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Wrap(
          spacing: 10,
          runSpacing: 12,
          children: _displayedLanguages.map((lang) {
            final isSelected = _selectedLanguages.contains(lang);
            return _buildChoiceChip(lang, isSelected, () => _handleLanguageTapped(lang));
          }).toList(),
        ),
      );
    } else if (_currentStep == 1) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Wrap(
          spacing: 10,
          runSpacing: 12,
          children: _displayedGenres.map((genre) {
            final isSelected = _selectedGenres.contains(genre);
            return _buildChoiceChip(genre, isSelected, () => _handleGenreTapped(genre));
          }).toList(),
        ),
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
          border: Border.all(color: isSelected ? Colors.white : Colors.white12, width: 1.5),
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
          IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70), onPressed: () => setState(() => _currentStep--))
        else
          const SizedBox(width: 48),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _canProceed ? Colors.white : Colors.white24,
            foregroundColor: _canProceed ? Colors.black : Colors.white38,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            elevation: _canProceed ? 8 : 0,
          ),
          onPressed: _canProceed
              ? () {
                  if (_currentStep < 2) {
                    setState(() => _currentStep++);
                  } else {
                    _finishOnboarding();
                  }
                }
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_currentStep == 2 ? 'Start Listening' : 'Next', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}
