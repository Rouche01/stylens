import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gostylens/widgets/floating_nav_bar.dart';

enum _ClosetViewMode { all, categories }

class ClosetMockItem {
  const ClosetMockItem({
    required this.id,
    required this.name,
    required this.category,
    required this.imageUrl,
    required this.aspectRatio,
  });

  final String id;
  final String name;
  final String category;
  final String imageUrl;

  /// Width / height. Used so masonry tiles keep a stable height before the
  /// network image loads.
  final double aspectRatio;
}

const _crossAxisCount = 3;
const _gridGap = 8.0;
const _tileRadius = 18.0;

const _categoryOrder = ['Tops', 'Bottoms', 'Outerwear', 'Shoes'];

const _mockItems = <ClosetMockItem>[
  ClosetMockItem(
    id: '1',
    name: 'Camel overcoat',
    category: 'Outerwear',
    aspectRatio: 3 / 5,
    imageUrl:
        'https://images.unsplash.com/photo-1539533018447-63fcce2678e3?auto=format&fit=crop&w=800&q=80',
  ),
  ClosetMockItem(
    id: '2',
    name: 'White tee',
    category: 'Tops',
    aspectRatio: 4 / 5,
    imageUrl:
        'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=800&q=80',
  ),
  ClosetMockItem(
    id: '3',
    name: 'Vintage denim',
    category: 'Bottoms',
    aspectRatio: 2 / 3,
    imageUrl:
        'https://images.unsplash.com/photo-1542272604-787c3835535d?auto=format&fit=crop&w=800&q=80',
  ),
  ClosetMockItem(
    id: '4',
    name: 'Court sneakers',
    category: 'Shoes',
    aspectRatio: 1,
    imageUrl:
        'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=800&q=80',
  ),
  ClosetMockItem(
    id: '5',
    name: 'Ivory knit',
    category: 'Tops',
    aspectRatio: 5 / 6,
    imageUrl:
        'https://images.unsplash.com/photo-1434389677669-e08b4cac3105?auto=format&fit=crop&w=800&q=80',
  ),
  ClosetMockItem(
    id: '6',
    name: 'Leather jacket',
    category: 'Outerwear',
    aspectRatio: 3 / 4,
    imageUrl:
        'https://images.unsplash.com/photo-1551028719-00167b16eac5?auto=format&fit=crop&w=800&q=80',
  ),
  ClosetMockItem(
    id: '7',
    name: 'Tailored trousers',
    category: 'Bottoms',
    aspectRatio: 3 / 5,
    imageUrl:
        'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?auto=format&fit=crop&w=800&q=80',
  ),
  ClosetMockItem(
    id: '8',
    name: 'Chelsea boots',
    category: 'Shoes',
    aspectRatio: 5 / 6,
    imageUrl:
        'https://images.unsplash.com/photo-1638247025967-b4e38f787b76?auto=format&fit=crop&w=800&q=80',
  ),
  ClosetMockItem(
    id: '9',
    name: 'Oxford stripe',
    category: 'Tops',
    aspectRatio: 3 / 4,
    imageUrl:
        'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?auto=format&fit=crop&w=800&q=80',
  ),
  ClosetMockItem(
    id: '10',
    name: 'Wool trench',
    category: 'Outerwear',
    aspectRatio: 2 / 3,
    imageUrl:
        'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?auto=format&fit=crop&w=800&q=80',
  ),
  ClosetMockItem(
    id: '11',
    name: 'Pleated skirt',
    category: 'Bottoms',
    aspectRatio: 4 / 5,
    imageUrl:
        'https://images.unsplash.com/photo-1583496661160-fb5886a0aaaa?auto=format&fit=crop&w=800&q=80',
  ),
  ClosetMockItem(
    id: '12',
    name: 'Loafers',
    category: 'Shoes',
    aspectRatio: 6 / 5,
    imageUrl:
        'https://images.unsplash.com/photo-1614252235316-8c857d38b5f4?auto=format&fit=crop&w=800&q=80',
  ),
  ClosetMockItem(
    id: '13',
    name: 'Ink hoodie',
    category: 'Tops',
    aspectRatio: 4 / 5,
    imageUrl:
        'https://images.unsplash.com/photo-1556821840-3a63f95609a7?auto=format&fit=crop&w=800&q=80',
  ),
  ClosetMockItem(
    id: '14',
    name: 'Rain coat',
    category: 'Outerwear',
    aspectRatio: 3 / 5,
    imageUrl:
        'https://images.unsplash.com/photo-1544923246-77307dd654cb?auto=format&fit=crop&w=800&q=80',
  ),
  ClosetMockItem(
    id: '15',
    name: 'Wide-leg linen',
    category: 'Bottoms',
    aspectRatio: 2 / 3,
    imageUrl:
        'https://images.unsplash.com/photo-1506629082955-511b1aa562c8?auto=format&fit=crop&w=800&q=80',
  ),
  ClosetMockItem(
    id: '16',
    name: 'Ballet flats',
    category: 'Shoes',
    aspectRatio: 1,
    imageUrl:
        'https://images.unsplash.com/photo-1543163521-1bf539c55dd2?auto=format&fit=crop&w=800&q=80',
  ),
];

class ClosetBrowseView extends StatefulWidget {
  const ClosetBrowseView({super.key});

  @override
  State<ClosetBrowseView> createState() => _ClosetBrowseViewState();
}

class _ClosetBrowseViewState extends State<ClosetBrowseView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();
  _ClosetViewMode _viewMode = _ClosetViewMode.all;
  bool _snappingHeader = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_rebuild);
  }

  @override
  void dispose() {
    _searchController.removeListener(_rebuild);
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    setState(() {});
    _pinScrollIfEmpty();
  }

  void _pinScrollIfEmpty() {
    if (_filteredItems.isNotEmpty) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset == 0) return;
    _scrollController.jumpTo(0);
  }

  void _dismissKeyboard() {
    _searchFocus.unfocus();
  }

  void _onViewModeChanged(_ClosetViewMode mode) {
    if (mode == _viewMode) return;
    _dismissKeyboard();
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.jumpTo(0);
    }
    setState(() => _viewMode = mode);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is! ScrollEndNotification) return false;
    if (_snappingHeader) return false;
    _snapHeaderIfNeeded();
    return false;
  }

  Future<void> _snapHeaderIfNeeded() async {
    if (!_scrollController.hasClients) return;
    final range = _ClosetHeaderMetrics.collapseRange(
      MediaQuery.paddingOf(context).top,
    );
    if (range <= 0) return;

    final offset = _scrollController.offset;
    if (offset <= 0.5 || offset >= range - 0.5) return;

    final target = offset / range >= 0.5 ? range : 0.0;
    _snappingHeader = true;
    try {
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _snappingHeader = false;
    }
  }

  List<ClosetMockItem> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _mockItems;
    return _mockItems
        .where(
          (item) =>
              item.name.toLowerCase().contains(query) ||
              item.category.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _filteredItems;
    final bottomPad = 16 + FloatingNavBar.contentBottomInset(context);

    final topInset = MediaQuery.paddingOf(context).top;
    final minHeader = _ClosetHeaderMetrics.minExtentFor(topInset);
    final maxHeader = _ClosetHeaderMetrics.maxExtentFor(topInset);

    return Scaffold(
      backgroundColor: cs.surfaceDim,
      // Search sits at the top; shrinking the body would crush the grid.
      resizeToAvoidBottomInset: false,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: CustomScrollView(
          controller: _scrollController,
          physics: items.isEmpty ? const NeverScrollableScrollPhysics() : null,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverResizingHeader(
              minExtentPrototype: SizedBox(height: minHeader),
              maxExtentPrototype: SizedBox(height: maxHeader),
              child: _ClosetHeader(
                minExtent: minHeader,
                maxExtent: maxHeader,
                topInset: topInset,
                backgroundColor: cs.surfaceDim,
                titleColor: cs.primary,
                toolbar: _ClosetToolbar(
                  searchController: _searchController,
                  searchFocus: _searchFocus,
                  viewMode: _viewMode,
                  onDismissKeyboard: _dismissKeyboard,
                  onViewModeChanged: _onViewModeChanged,
                ),
              ),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(32, 0, 32, bottomPad),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No pieces match “${_searchController.text.trim()}”.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Metropolis',
                            fontSize: 14,
                            color: cs.primary.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _searchController.clear,
                          style: TextButton.styleFrom(
                            foregroundColor: cs.primary,
                            textStyle: const TextStyle(
                              fontFamily: 'Metropolis',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Clear search'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_viewMode == _ClosetViewMode.all)
              ..._allSlivers(items, bottomPad)
            else
              ..._categorySlivers(items, bottomPad),
          ],
        ),
      ),
    );
  }

  List<Widget> _allSlivers(List<ClosetMockItem> items, double bottomPad) {
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
        sliver: SliverMasonryGrid.count(
          crossAxisCount: _crossAxisCount,
          mainAxisSpacing: _gridGap,
          crossAxisSpacing: _gridGap,
          childCount: items.length,
          itemBuilder: (context, index) => _ClosetItemTile(item: items[index]),
        ),
      ),
    ];
  }

  List<Widget> _categorySlivers(List<ClosetMockItem> items, double bottomPad) {
    final slivers = <Widget>[];
    final cs = Theme.of(context).colorScheme;
    final present = _categoryOrder
        .where((cat) => items.any((item) => item.category == cat))
        .toList();

    for (var i = 0; i < present.length; i++) {
      final category = present[i];
      final group = items.where((item) => item.category == category).toList();
      final isLast = i == present.length - 1;

      slivers.add(
        SliverMainAxisGroup(
          slivers: [
            PinnedHeaderSliver(
              child: _CategorySectionHeader(
                label: category,
                count: group.length,
                backgroundColor: cs.surfaceDim,
                foregroundColor: cs.primary,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, isLast ? bottomPad : 16),
              sliver: SliverAlignedGrid.count(
                crossAxisCount: _crossAxisCount,
                mainAxisSpacing: _gridGap,
                crossAxisSpacing: _gridGap,
                itemCount: group.length,
                itemBuilder: (context, index) =>
                    _ClosetItemTile(item: group[index]),
              ),
            ),
          ],
        ),
      );
    }

    return slivers;
  }
}

abstract final class _ClosetHeaderMetrics {
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

class _ClosetHeader extends StatelessWidget {
  const _ClosetHeader({
    required this.minExtent,
    required this.maxExtent,
    required this.topInset,
    required this.backgroundColor,
    required this.titleColor,
    required this.toolbar,
  });

  final double minExtent;
  final double maxExtent;
  final double topInset;
  final Color backgroundColor;
  final Color titleColor;
  final Widget toolbar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final range = maxExtent - minExtent;
        final rawT = range == 0
            ? 0.0
            : ((maxExtent - height) / range).clamp(0.0, 1.0);
        final titleT = Curves.easeInOutCubic.transform(rawT);
        final titleScale = Tween<double>(
          begin: 1,
          end: _ClosetHeaderMetrics.titleScale,
        ).transform(titleT);
        final titleWeight = rawT >= 0.98 ? FontWeight.w500 : FontWeight.w600;
        final titleSlot = Tween<double>(
          begin: _ClosetHeaderMetrics.expandedTitleSlot,
          end: _ClosetHeaderMetrics.collapsedTitleSlot,
        ).transform(rawT);
        final topPad = Tween<double>(begin: 8, end: 6).transform(rawT);
        final gap = Tween<double>(begin: 16, end: 8).transform(rawT);
        final bottomPad = Tween<double>(begin: 16, end: 8).transform(rawT);

        return SizedBox(
          height: height,
          width: double.infinity,
          child: ColoredBox(
            color: backgroundColor,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                topInset + topPad,
                16,
                bottomPad,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: titleSlot,
                    width: double.infinity,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        maxHeight: _ClosetHeaderMetrics.expandedTitleSlot,
                        child: Transform.scale(
                          alignment: Alignment.centerLeft,
                          scale: titleScale,
                          child: Text(
                            'Your Closet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'ClashDisplay',
                              fontSize: _ClosetHeaderMetrics.expandedTitleSize,
                              fontWeight: titleWeight,
                              height: 1.1,
                              letterSpacing: -0.3,
                              color: titleColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  toolbar,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderEdgeFade extends StatelessWidget {
  const _HeaderEdgeFade({required this.color});

  final Color color;

  static const _height = 16.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color,
              color,
              color.withValues(alpha: 0.7),
              color.withValues(alpha: 0.32),
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.18, 0.48, 0.76, 1.0],
          ),
        ),
      ),
    );
  }
}

class _ClosetToolbar extends StatelessWidget {
  const _ClosetToolbar({
    required this.searchController,
    required this.searchFocus,
    required this.viewMode,
    required this.onDismissKeyboard,
    required this.onViewModeChanged,
  });

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final _ClosetViewMode viewMode;
  final VoidCallback onDismissKeyboard;
  final ValueChanged<_ClosetViewMode> onViewModeChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: searchController,
              focusNode: searchFocus,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.search,
              scrollPadding: EdgeInsets.zero,
              onTapOutside: (_) => onDismissKeyboard(),
              onSubmitted: (_) => onDismissKeyboard(),
              style: const TextStyle(
                fontFamily: 'Metropolis',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search pieces',
                hintStyle: TextStyle(
                  fontFamily: 'Metropolis',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.primary.withValues(alpha: 0.4),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: cs.primary.withValues(alpha: 0.45),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 42,
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        onPressed: searchController.clear,
                        icon: Icon(
                          Icons.cancel,
                          size: 18,
                          color: cs.primary.withValues(alpha: 0.45),
                        ),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 42,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: cs.primary.withValues(alpha: 0.18),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: cs.primary.withValues(alpha: 0.18),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: cs.primary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<_ClosetViewMode>(
          initialValue: viewMode,
          onSelected: onViewModeChanged,
          tooltip: 'View',
          offset: const Offset(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          itemBuilder: (context) => const [
            PopupMenuItem(value: _ClosetViewMode.all, child: Text('All')),
            PopupMenuItem(
              value: _ClosetViewMode.categories,
              child: Text('Categories'),
            ),
          ],
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  viewMode == _ClosetViewMode.all ? 'All' : 'Categories',
                  style: TextStyle(
                    fontFamily: 'Metropolis',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.secondary,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.expand_more, size: 18, color: cs.secondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategorySectionHeader extends StatelessWidget {
  const _CategorySectionHeader({
    required this.label,
    required this.count,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final int count;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: foregroundColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  count == 1 ? '1 piece' : '$count pieces',
                  style: TextStyle(
                    fontFamily: 'Metropolis',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: foregroundColor.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ),
        IgnorePointer(child: _HeaderEdgeFade(color: backgroundColor)),
      ],
    );
  }
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child});

  final Widget child;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _ClosetItemTile extends StatelessWidget {
  const _ClosetItemTile({required this.item});

  final ClosetMockItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _PressableScale(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_tileRadius),
        child: AspectRatio(
          aspectRatio: item.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: cs.primary.withValues(alpha: 0.08)),
              Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return ColoredBox(
                    color: cs.primary.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.checkroom_outlined,
                      color: cs.primary.withValues(alpha: 0.35),
                    ),
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        cs.primary.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 28, 10, 9),
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Metropolis',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
