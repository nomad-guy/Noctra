import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../services/metadata/artist_metadata_service.dart';
import '../../../services/ytdlp/music_service.dart';

class OnboardingArtistPicker extends StatefulWidget {
  final List<String> selectedLanguages;
  final List<String> selectedArtists;
  final Function(String artistName) onToggle;

  const OnboardingArtistPicker({
    super.key,
    this.selectedLanguages = const [],
    required this.selectedArtists,
    required this.onToggle,
  });

  static const int maxArtistsLimit = 50;

  static const Map<String, List<String>> languageArtists = {
    'hindi': ['Arijit Singh', 'Shreya Ghoshal', 'Pritam', 'Atif Aslam', 'Badshah', 'Sachin-Jigar'],
    'punjabi': ['Sidhu Moose Wala', 'Karan Aujla', 'Diljit Dosanjh', 'AP Dhillon', 'Shubh'],
    'tamil': ['Anirudh Ravichander', 'A.R. Rahman', 'Sid Sriram', 'Yuvan Shankar Raja', 'Harris Jayaraj'],
    'telugu': ['Devi Sri Prasad', 'S. Thaman', 'Sid Sriram', 'Anurag Kulkarni', 'Ram Miriyala'],
    'malayalam': ['Sushin Shyam', 'Hesham Abdul Wahab', 'K.S. Harisankar', 'Job Kurian'],
    'kannada': ['Sanjith Hegde', 'Ravi Basrur', 'Charan Raj', 'Vijay Prakash'],
    'marathi': ['Ajay-Atul', 'Swapnil Bandodkar', 'Avadhoot Gupte'],
    'bengali': ['Anupam Roy', 'Arijit Singh', 'Shreya Ghoshal', 'Rupam Islam'],
    'urdu': ['Atif Aslam', 'Ali Sethi', 'Rahat Fateh Ali Khan', 'Asim Azhar'],
    'english': ['The Weeknd', 'Taylor Swift', 'Drake', 'Billie Eilish', 'Dua Lipa', 'Coldplay'],
    'spanish': ['Bad Bunny', 'Rosalía', 'J Balvin', 'Peso Pluma', 'Karol G'],
    'korean': ['BTS', 'BLACKPINK', 'NewJeans', 'Stray Kids', 'IU'],
    'japanese': ['YOASOBI', 'Kenshi Yonezu', 'Fujii Kaze', 'Ado'],
    'french': ['Stromae', 'Indila', 'Gims', 'Aya Nakamura'],
  };

  static const List<String> popularArtists = [
    'Arijit Singh', 'The Weeknd', 'Sidhu Moose Wala', 'Diljit Dosanjh',
    'Taylor Swift', 'Pritam', 'Karan Aujla', 'AP Dhillon',
    'Fly By Midnight', 'Shreya Ghoshal', 'Dua Lipa', 'Atif Aslam',
    'Drake', 'Coldplay', 'Billie Eilish', 'Badshah',
  ];

  @override
  State<OnboardingArtistPicker> createState() => _OnboardingArtistPickerState();
}

class _OnboardingArtistPickerState extends State<OnboardingArtistPicker> {
  final Map<String, String?> _resolvedPhotos = {};
  late final List<String> _displayedArtists;

  @override
  void initState() {
    super.initState();
    final ordered = <String>[];
    for (final lang in widget.selectedLanguages) {
      final list = OnboardingArtistPicker.languageArtists[lang.toLowerCase().trim()];
      if (list != null) {
        for (final a in list) {
          if (!ordered.contains(a)) ordered.add(a);
        }
      }
    }
    for (final a in OnboardingArtistPicker.popularArtists) {
      if (!ordered.contains(a)) ordered.add(a);
    }
    _displayedArtists = ordered.take(30).toList();
    _loadPhotos(_displayedArtists);
    _fetchDynamicArtists();
  }

  void _fetchDynamicArtists() async {
    final dynamicArtists = <String>[];
    for (final lang in widget.selectedLanguages) {
      try {
        final songs = await MusicService.searchTracks('$lang top hits');
        for (final s in songs) {
          final a = s.artist.split(RegExp(r'[,&/]| feat\.? | ft\.? ', caseSensitive: false)).first.trim();
          if (a.length > 2 && !dynamicArtists.contains(a)) {
            dynamicArtists.add(a);
            if (dynamicArtists.length >= 20) break;
          }
        }
      } catch (_) {}
    }
    if (dynamicArtists.isNotEmpty && mounted) {
      setState(() {
        for (final a in dynamicArtists.reversed) {
          if (_displayedArtists.length >= OnboardingArtistPicker.maxArtistsLimit) break;
          if (!_displayedArtists.contains(a)) {
            _displayedArtists.insert(0, a);
          }
        }
      });
      _loadPhotos(dynamicArtists);
    }
  }

  void _loadPhotos(List<String> artists) async {
    try {
      final futures = artists.where((a) => !_resolvedPhotos.containsKey(a)).map((artist) async {
        final meta = await ArtistMetadataService.fetchArtistInfo(artist);
        return MapEntry(artist, meta.imageUrl);
      });
      final results = await Future.wait(futures);
      if (mounted) {
        setState(() {
          for (final entry in results) {
            _resolvedPhotos[entry.key] = entry.value;
          }
        });
      }
    } catch (_) {}
  }

  void _handleArtistTapped(String artist) async {
    HapticFeedback.selectionClick();
    widget.onToggle(artist);
    final willBeSelected = !widget.selectedArtists.contains(artist);

    if (willBeSelected && _displayedArtists.length < OnboardingArtistPicker.maxArtistsLimit) {
      final similar = await ArtistMetadataService.fetchDynamicSimilarArtists(artist);
      if (similar.isNotEmpty && mounted) {
        final newToLoad = <String>[];
        final insertIndex = (_displayedArtists.indexOf(artist) + 1).clamp(0, _displayedArtists.length);
        int offset = 0;

        for (final sim in similar) {
          if (_displayedArtists.length >= OnboardingArtistPicker.maxArtistsLimit) break;
          if (!_displayedArtists.contains(sim)) {
            _displayedArtists.insert(insertIndex + offset, sim);
            newToLoad.add(sim);
            offset++;
          }
        }
        if (newToLoad.isNotEmpty) {
          setState(() {});
          _loadPhotos(newToLoad);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.82,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _displayedArtists.length,
      itemBuilder: (context, i) {
        final artist = _displayedArtists[i];
        final isSelected = widget.selectedArtists.contains(artist);
        final photo = _resolvedPhotos[artist];

        return GestureDetector(
          onTap: () => _handleArtistTapped(artist),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white12,
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: ClipOval(
                        child: photo != null && photo.isNotEmpty
                            ? Image.network(
                                photo,
                                fit: BoxFit.cover,
                                cacheWidth: 150,
                                cacheHeight: 150,
                                errorBuilder: (_, __, ___) => _fallbackAvatar(),
                              )
                            : _fallbackAvatar(),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : NoirColors.blackTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: const Icon(Icons.person_rounded, size: 30, color: Colors.white38),
    );
  }
}
