import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../services/metadata/artist_metadata_service.dart';

class OnboardingArtistPicker extends StatefulWidget {
  final List<String> selectedArtists;
  final Function(String artistName) onToggle;

  const OnboardingArtistPicker({
    super.key,
    required this.selectedArtists,
    required this.onToggle,
  });

  static const int maxArtistsLimit = 50;

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
  final List<String> _displayedArtists = List.from(OnboardingArtistPicker.popularArtists);

  @override
  void initState() {
    super.initState();
    _loadPhotos(_displayedArtists);
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
