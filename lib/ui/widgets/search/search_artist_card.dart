import 'package:flutter/material.dart';
import '../../screens/artist_screen.dart';
import '../../../shared/widgets/glass_card.dart';

class SearchArtistCard extends StatelessWidget {
  final String artistName;
  final String? artistImageUrl;
  final bool isDark;

  const SearchArtistCard({
    super.key,
    required this.artistName,
    this.artistImageUrl,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (c) => ArtistScreen(
              artistName: artistName,
              artistImageUrl: artistImageUrl,
            ),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  isDark ? const Color(0xFF222222) : const Color(0xFFDCDCDC),
              backgroundImage: artistImageUrl != null
                  ? NetworkImage(artistImageUrl!)
                  : null,
              child: artistImageUrl == null
                  ? Icon(
                      Icons.person_rounded,
                      color: isDark ? Colors.white70 : Colors.black87,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          artistName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Official Artist Profile • Explore discography & creations',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}
