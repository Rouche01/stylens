import 'package:gostylens/models/closet_item.dart';

enum ClosetViewMode { all, categories }

abstract final class ClosetBrowseLayout {
  static const crossAxisCount = 3;
  static const gridGap = 8.0;
  static const tileRadius = 18.0;
  static const toolbarControlRadius = 12.0;

  static const skeletonAspectRatios = <double>[
    4 / 5,
    3 / 4,
    2 / 3,
    5 / 6,
    4 / 5,
    3 / 5,
    1,
    3 / 4,
    4 / 5,
  ];
}

abstract final class ClosetHeaderMetrics {
  static const expandedTitleSize = 28.0;
  static const collapsedTitleSize = 18.0;
  static const titleScale = collapsedTitleSize / expandedTitleSize;
  static const toolbarHeight = 42.0;
  static const expandedTitleSlot = 34.0;
  static const collapsedTitleSlot = 22.0;

  static double maxExtentFor(double topInset) =>
      topInset + 8 + expandedTitleSlot + 16 + toolbarHeight + 16;

  static double minExtentFor(double topInset) =>
      topInset + 6 + collapsedTitleSlot + 8 + toolbarHeight + 8;

  static double collapseRange(double topInset) =>
      maxExtentFor(topInset) - minExtentFor(topInset);
}

bool closetItemMatchesQuery(ClosetItem item, String query) {
  if (query.isEmpty) return true;
  return item.displayName.toLowerCase().contains(query) ||
      item.label.toLowerCase().contains(query) ||
      item.displayCategory.toLowerCase().contains(query) ||
      item.subcategory.toLowerCase().contains(query) ||
      item.color.toLowerCase().contains(query);
}
