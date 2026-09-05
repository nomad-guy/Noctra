import 'package:flutter/material.dart';
import '../../../data/models/catalog_topic.dart';
import '../../../shared/widgets/glass_card.dart';

class SearchCatalogGrid extends StatelessWidget {
  final bool isDark;
  final List<CatalogTopic>? catalogTopics;
  final bool isLoadingCatalogTopics;
  final ValueChanged<String>? onGenreTap;

  const SearchCatalogGrid({
    super.key,
    required this.isDark,
    this.catalogTopics,
    this.isLoadingCatalogTopics = false,
    this.onGenreTap,
  });

  @override
  Widget build(BuildContext context) {
    final liveTopics = catalogTopics ?? const <CatalogTopic>[];
    final globalGenres = liveTopics.asMap().entries.map((entry) {
      final topic = entry.value;
      const icons = [
        Icons.auto_awesome_rounded,
        Icons.graphic_eq_rounded,
        Icons.music_note_rounded,
        Icons.headphones_rounded,
        Icons.bolt_rounded,
        Icons.nightlight_round
      ];
      return {
        'title': topic.title,
        'category': topic.category,
        'query': topic.query,
        'icon': icons[entry.key % icons.length]
      };
    }).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isLoadingCatalogTopics
                    ? 'Updating live catalog...'
                    : 'Explore Live Catalogs & Genres',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${globalGenres.length} Catalogs',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (globalGenres.isEmpty && !isLoadingCatalogTopics)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: Text('Catalog is temporarily unavailable.')),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.85,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: globalGenres.length,
            itemBuilder: (context, idx) {
              final g = globalGenres[idx];
              return GlassCard(
                radius: 14,
                padding: const EdgeInsets.all(12),
                onTap: () => onGenreTap?.call(g['query'] as String),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(g['icon'] as IconData,
                            size: 20,
                            color: isDark ? Colors.white : Colors.black),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.black12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            g['category'] as String,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      g['title'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
