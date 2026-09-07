import 'package:flutter/material.dart';

enum FolderSortOption {
  defaultOrder,
  titleAZ,
  artistAZ,
  durationLongest,
  durationShortest,
}

class FolderDetailHeader extends StatelessWidget {
  final String folderName;
  final bool isDark;
  final bool showSearch;
  final FolderSortOption sortOption;
  final TextEditingController searchCtrl;
  final String searchQuery;
  final VoidCallback onBack;
  final VoidCallback onToggleSearch;
  final ValueChanged<FolderSortOption> onSortSelected;
  final VoidCallback onClearSearch;

  const FolderDetailHeader({
    super.key,
    required this.folderName,
    required this.isDark,
    required this.showSearch,
    required this.sortOption,
    required this.searchCtrl,
    required this.searchQuery,
    required this.onBack,
    required this.onToggleSearch,
    required this.onSortSelected,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: isDark ? Colors.white : Colors.black),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  folderName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  showSearch ? Icons.search_off_rounded : Icons.search_rounded,
                  color: isDark ? Colors.white70 : Colors.black87,
                  size: 20,
                ),
                tooltip: 'Search tracks in playlist',
                onPressed: onToggleSearch,
              ),
              PopupMenuButton<FolderSortOption>(
                icon: Icon(
                  Icons.sort_rounded,
                  color: isDark ? Colors.white70 : Colors.black87,
                  size: 20,
                ),
                tooltip: 'Sort playlist',
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                onSelected: onSortSelected,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: FolderSortOption.defaultOrder,
                    child: Text('Default (Added Order)'),
                  ),
                  PopupMenuItem(
                    value: FolderSortOption.titleAZ,
                    child: Text('Title (A to Z)'),
                  ),
                  PopupMenuItem(
                    value: FolderSortOption.artistAZ,
                    child: Text('Artist (A to Z)'),
                  ),
                  PopupMenuItem(
                    value: FolderSortOption.durationLongest,
                    child: Text('Duration (Longest first)'),
                  ),
                  PopupMenuItem(
                    value: FolderSortOption.durationShortest,
                    child: Text('Duration (Shortest first)'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: searchCtrl,
                autofocus: true,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Filter in "$folderName"...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: onClearSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
