import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gostylens/models/closet_item.dart';
import 'package:gostylens/pages/closet/closet_browse_layout.dart';
import 'package:gostylens/pages/closet/closet_empty.dart';
import 'package:gostylens/pages/closet/closet_header.dart';
import 'package:gostylens/pages/closet/closet_tile.dart';
import 'package:skeletonizer/skeletonizer.dart';

List<Widget> closetBrowseBodySlivers({
  required BuildContext context,
  required ClosetViewMode viewMode,
  required List<ClosetItem> items,
  required double bottomPad,
  required bool showSkeleton,
  required bool catalogEmpty,
  required bool processingEmpty,
  required bool failedEmpty,
  required bool hasAskChrome,
  required ClosetEmptyKind emptyKind,
  required String? errorMessage,
  required String query,
  required Key dockInsetKey,
  required VoidCallback onRetry,
  required VoidCallback onClearSearch,
  required VoidCallback onCapture,
}) {
  final cs = Theme.of(context).colorScheme;

  if (showSkeleton) {
    return _withDockScrollInset(
      _skeletonSlivers(context, viewMode),
      bottomPad,
      dockInsetKey,
    );
  }
  if (errorMessage != null &&
      catalogEmpty &&
      !processingEmpty &&
      !failedEmpty) {
    return [
      _messageSliver(
        cs: cs,
        bottomPad: bottomPad,
        message: errorMessage,
        actionLabel: 'Retry',
        onAction: onRetry,
      ),
    ];
  }
  if (catalogEmpty) {
    return [
      _emptyCatalogSliver(
        hasAskChrome: hasAskChrome,
        bottomPad: bottomPad,
        emptyKind: emptyKind,
        onCapture: onCapture,
      ),
    ];
  }
  if (items.isEmpty) {
    return [
      _messageSliver(
        cs: cs,
        bottomPad: bottomPad,
        message: 'No pieces match “$query”.',
        actionLabel: 'Clear search',
        onAction: onClearSearch,
      ),
    ];
  }
  final grid = viewMode == ClosetViewMode.all
      ? _allSlivers(items)
      : _categorySlivers(context, items);
  return _withDockScrollInset(grid, bottomPad, dockInsetKey);
}

List<Widget> _withDockScrollInset(
  List<Widget> slivers,
  double bottomPad,
  Key dockInsetKey,
) {
  return [
    ...slivers,
    SliverToBoxAdapter(
      child: SizedBox(key: dockInsetKey, height: bottomPad),
    ),
  ];
}

Widget _emptyCatalogSliver({
  required bool hasAskChrome,
  required double bottomPad,
  required ClosetEmptyKind emptyKind,
  required VoidCallback onCapture,
}) {
  if (hasAskChrome) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 8, 32, bottomPad),
        child: ClosetEmptyState(onCaptureOutfit: onCapture, kind: emptyKind),
      ),
    );
  }
  return ClosetEmptySliver(
    bottomPad: bottomPad,
    onCaptureOutfit: onCapture,
    kind: emptyKind,
  );
}

Widget _messageSliver({
  required ColorScheme cs,
  required double bottomPad,
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  return SliverFillRemaining(
    hasScrollBody: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(32, 0, 32, bottomPad),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Metropolis',
                fontSize: 14,
                color: cs.primary.withValues(alpha: 0.55),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  textStyle: const TextStyle(
                    fontFamily: 'Metropolis',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Widget _masonrySliver({
  Key? key,
  required int itemCount,
  required IndexedWidgetBuilder itemBuilder,
  Key? Function(int index)? keyOf,
}) {
  return SliverPadding(
    key: key,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    sliver: SliverMasonryGrid(
      gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ClosetBrowseLayout.crossAxisCount,
      ),
      mainAxisSpacing: ClosetBrowseLayout.gridGap,
      crossAxisSpacing: ClosetBrowseLayout.gridGap,
      delegate: SliverChildBuilderDelegate(
        itemBuilder,
        childCount: itemCount,
        findChildIndexCallback: keyOf == null
            ? null
            : (key) {
                for (var i = 0; i < itemCount; i++) {
                  if (keyOf(i) == key) return i;
                }
                return null;
              },
      ),
    ),
  );
}

List<Widget> _skeletonSlivers(BuildContext context, ClosetViewMode viewMode) {
  if (viewMode == ClosetViewMode.categories) {
    return _categorySkeletonSlivers(context);
  }
  const ratios = ClosetBrowseLayout.skeletonAspectRatios;
  return [
    _masonrySliver(
      key: const ValueKey('closet-skeleton'),
      itemCount: ratios.length,
      keyOf: (index) => ValueKey('closet-skeleton-tile-$index'),
      itemBuilder: (context, index) => Skeletonizer(
        key: ValueKey('closet-skeleton-tile-$index'),
        enabled: true,
        child: ClosetSkeletonTile(aspectRatio: ratios[index]),
      ),
    ),
  ];
}

List<Widget> _categorySkeletonSlivers(BuildContext context) {
  const sections = [('Tops', 3), ('Bottoms', 3), ('Outerwear', 3)];
  final cs = Theme.of(context).colorScheme;
  final slivers = <Widget>[];
  var aspectIndex = 0;
  const ratios = ClosetBrowseLayout.skeletonAspectRatios;

  for (var i = 0; i < sections.length; i++) {
    final section = sections[i];
    final count = section.$2;
    final tileRatios = [
      for (var j = 0; j < count; j++) ratios[aspectIndex++ % ratios.length],
    ];

    slivers.add(
      SliverMainAxisGroup(
        slivers: [
          PinnedHeaderSliver(
            child: ClosetCategorySectionHeader(
              label: section.$1,
              count: count,
              backgroundColor: cs.surfaceDim,
              foregroundColor: cs.primary,
            ),
          ),
          _masonrySliver(
            key: i == 0 ? const ValueKey('closet-skeleton') : null,
            itemCount: count,
            keyOf: (index) => ValueKey('closet-skeleton-$i-$index'),
            itemBuilder: (context, index) => Skeletonizer(
              key: ValueKey('closet-skeleton-$i-$index'),
              enabled: true,
              child: ClosetSkeletonTile(aspectRatio: tileRatios[index]),
            ),
          ),
        ],
      ),
    );
  }

  return slivers;
}

List<Widget> _allSlivers(List<ClosetItem> items) {
  return [
    _masonrySliver(
      key: const ValueKey('closet-all-grid'),
      itemCount: items.length,
      keyOf: (index) => ValueKey(items[index].id),
      itemBuilder: (context, index) =>
          ClosetItemTile(key: ValueKey(items[index].id), item: items[index]),
    ),
  ];
}

List<Widget> _categorySlivers(BuildContext context, List<ClosetItem> items) {
  final slivers = <Widget>[];
  final cs = Theme.of(context).colorScheme;
  final present = ClosetItem.displayCategoryOrder
      .where((cat) => items.any((item) => item.displayCategory == cat))
      .toList();

  for (var i = 0; i < present.length; i++) {
    final category = present[i];
    final group = ClosetItem.packForMasonry(
      items.where((item) => item.displayCategory == category).toList(),
    );

    slivers.add(
      SliverMainAxisGroup(
        key: ValueKey('closet-cat-$category'),
        slivers: [
          PinnedHeaderSliver(
            child: ClosetCategorySectionHeader(
              label: category,
              count: group.length,
              backgroundColor: cs.surfaceDim,
              foregroundColor: cs.primary,
            ),
          ),
          _masonrySliver(
            itemCount: group.length,
            keyOf: (index) => ValueKey(group[index].id),
            itemBuilder: (context, index) => ClosetItemTile(
              key: ValueKey(group[index].id),
              item: group[index],
            ),
          ),
        ],
      ),
    );
  }

  return slivers;
}
