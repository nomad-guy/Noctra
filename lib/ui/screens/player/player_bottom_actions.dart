import 'package:flutter/material.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../core/utils/localization/localization_keys.dart';
import '../../../core/utils/localization/localization_scope.dart';
import '../../../data/models/song_model.dart';
import '../../widgets/ai_radio_sheet.dart';
import '../artist_screen.dart';

class PlayerBottomActions extends StatelessWidget {
  final Song song;

  const PlayerBottomActions({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final tokens = context.noctraTokens;

    return Row(children: [
      Expanded(
        child: InkWell(
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (c) => AIRadioSheet(seedSong: song),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.subtleBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome,
                    size: 14, color: tokens.secondaryAccent),
                const SizedBox(width: 6),
                Text(
                  context.tr(L10nKeys.aiRadio),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(MaterialPageRoute(
              builder: (c) => ArtistScreen(
                artistName: song.artist,
                artistImageUrl: song.artworkUrl,
              ),
            ));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.subtleBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: tokens.elevatedSurface,
                  backgroundImage: song.artworkUrl != null
                      ? NetworkImage(song.artworkUrl!)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.secondaryText,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 11, color: tokens.tertiaryText),
              ],
            ),
          ),
        ),
      ),
    ]);
  }
}
