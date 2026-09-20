import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:gostylens/core/managers/closet_manager.dart';
import 'package:gostylens/models/closet_item.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/navigation/app_routes.dart';
import 'package:gostylens/pages/closet/closet_ask_banner.dart';
import 'package:gostylens/pages/closet/closet_empty.dart';
import 'package:gostylens/widgets/floating_nav_bar.dart';
import 'package:gostylens/widgets/image_with_fallback.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

enum _ClosetViewMode { all, categories }

const _crossAxisCount = 3;
const _gridGap = 8.0;
const _tileRadius = 18.0;

const _skeletonAspectRatios = <double>[
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

bool _itemMatchesQuery(ClosetItem item, String query) {
  if (query.isEmpty) return true;
  return item.displayName.toLowerCase().contains(query) ||
      item.label.toLowerCase().contains(query) ||
      item.displayCategory.toLowerCase().contains(query) ||
      item.subcategory.toLowerCase().contains(query) ||
      item.color.toLowerCase().contains(query);
}

class ClosetBrowseView extends StatefulWidget {
  const ClosetBrowseView({super.key});

  @override
  State<ClosetBrowseView> createState() => _ClosetBrowseViewState();
}

class _ClosetBrowseViewState extends State<ClosetBrowseView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();
  _ClosetViewMode _viewMode = _ClosetViewMode.categories;
  bool _snappingHeader = false;

  /// Avoids an empty-state flash before the first [ClosetManager.fetchItems]
  /// call (scheduled after this frame so notifyListeners is not during build).
  bool _awaitingInitial = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ClosetManager>().fetchItems().whenComplete(() {
        if (mounted) setState(() => _awaitingInitial = false);
      });
      unawaited(context.read<ClosetManager>().fetchPendingMatches());
    });
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
    final items = _filter(context.read<ClosetManager>().items);
    if (items.isNotEmpty) return;
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

  List<ClosetItem> _filter(List<ClosetItem> items) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((item) => _itemMatchesQuery(item, query)).toList();
  }

  Future<void> _refresh() {
    final closet = context.read<ClosetManager>();
    return Future.wait([
      closet.fetchItems(forceRefresh: true),
      closet.fetchPendingMatches(),
    ]);
  }

  void _openCapture() {
    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell != null) {
      shell.goBranch(1);
      return;
    }
    GoRouter.maybeOf(context)?.go(AppRoutes.capture);
  }

  /// Sheet is the next plan item.
  void _openAskSheet() {}

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dockClearance = 16 + FloatingNavBar.contentBottomInset(context);

    final topInset = MediaQuery.paddingOf(context).top;
    final minHeader = _ClosetHeaderMetrics.minExtentFor(topInset);
    final maxHeader = _ClosetHeaderMetrics.maxExtentFor(topInset);

    return Scaffold(
      backgroundColor: cs.surfaceDim,
      // Search sits at the top; shrinking the body would crush the grid.
      resizeToAvoidBottomInset: false,
      body: Consumer<ClosetManager>(
        builder: (context, manager, _) {
          final items = _filter(manager.items);
          final catalogEmpty = manager.items.isEmpty;
          final processingEmpty = catalogEmpty && manager.isProcessing;
          final failedEmpty = catalogEmpty && manager.isFailedEmpty;
          final showChip = !catalogEmpty && manager.isProcessing;
          final showSkeleton =
              catalogEmpty &&
              !processingEmpty &&
              !failedEmpty &&
              (manager.isLoading || (_awaitingInitial && !manager.hasLoaded));
          final query = _searchController.text.trim();
          final bottomPad =
              dockClearance +
              (showChip ? ClosetProcessingDockChip.scrollReserve(context) : 0);

          final emptyKind = processingEmpty
              ? ClosetEmptyKind.processing
              : failedEmpty
              ? ClosetEmptyKind.failed
              : ClosetEmptyKind.idle;

          final physics = showSkeleton
              ? const NeverScrollableScrollPhysics()
              : items.isEmpty
              ? const AlwaysScrollableScrollPhysics()
              : null;

          return Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: RefreshIndicator(
                  color: cs.primary,
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: physics,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
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
                          onTitleLongPress: kDebugMode
                              ? () {
                                  HapticFeedback.selectionClick();
                                  manager.debugCycleWaitChrome();
                                }
                              : null,
                        ),
                      ),
                      if (manager.askSettle != null ||
                          manager.currentAsk != null)
                        SliverToBoxAdapter(
                          child: ClosetAskBanner(
                            ask: manager.currentAsk,
                            settle: manager.askSettle,
                            onOpenAsk: _openAskSheet,
                          ),
                        ),
                      if (showSkeleton)
                        ..._skeletonSlivers(bottomPad)
                      else if (manager.error != null &&
                          catalogEmpty &&
                          !processingEmpty &&
                          !failedEmpty)
                        _messageSliver(
                          cs: cs,
                          bottomPad: bottomPad,
                          message: manager.error!,
                          actionLabel: 'Retry',
                          onAction: _refresh,
                        )
                      else if (catalogEmpty)
                        _emptyCatalogSliver(
                          manager: manager,
                          bottomPad: bottomPad,
                          emptyKind: emptyKind,
                        )
                      else if (items.isEmpty)
                        _messageSliver(
                          cs: cs,
                          bottomPad: bottomPad,
                          message: 'No pieces match “$query”.',
                          actionLabel: 'Clear search',
                          onAction: _searchController.clear,
                        )
                      else if (_viewMode == _ClosetViewMode.all)
                        ..._allSlivers(items, bottomPad)
                      else
                        ..._categorySlivers(items, bottomPad),
                    ],
                  ),
                ),
              ),
              if (showChip)
                Positioned(
                  left: ClosetProcessingDockChip.sideInset,
                  right: ClosetProcessingDockChip.sideInset,
                  bottom: ClosetProcessingDockChip.bottomOffset(context),
                  child: const Align(
                    alignment: Alignment.bottomCenter,
                    child: ClosetProcessingDockChip(
                      key: ValueKey('closet-processing-chip'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyCatalogSliver({
    required ClosetManager manager,
    required double bottomPad,
    required ClosetEmptyKind emptyKind,
  }) {
    if (manager.askSettle != null || manager.currentAsk != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(32, 8, 32, bottomPad),
          child: ClosetEmptyState(
            onCaptureOutfit: _openCapture,
            kind: emptyKind,
          ),
        ),
      );
    }
    return ClosetEmptySliver(
      bottomPad: bottomPad,
      onCaptureOutfit: _openCapture,
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

  List<Widget> _skeletonSlivers(double bottomPad) {
    if (_viewMode == _ClosetViewMode.categories) {
      return _categorySkeletonSlivers(bottomPad);
    }
    return [
      Skeletonizer.sliver(
        key: const ValueKey('closet-skeleton'),
        enabled: true,
        child: SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: _crossAxisCount,
            mainAxisSpacing: _gridGap,
            crossAxisSpacing: _gridGap,
            childCount: _skeletonAspectRatios.length,
            itemBuilder: (context, index) =>
                _ClosetSkeletonTile(aspectRatio: _skeletonAspectRatios[index]),
          ),
        ),
      ),
    ];
  }

  List<Widget> _categorySkeletonSlivers(double bottomPad) {
    const sections = [('Tops', 3), ('Bottoms', 3), ('Outerwear', 3)];
    final cs = Theme.of(context).colorScheme;
    final slivers = <Widget>[];
    var aspectIndex = 0;

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final count = section.$2;
      final isLast = i == sections.length - 1;
      final ratios = [
        for (var j = 0; j < count; j++)
          _skeletonAspectRatios[aspectIndex++ % _skeletonAspectRatios.length],
      ];

      slivers.add(
        SliverMainAxisGroup(
          slivers: [
            PinnedHeaderSliver(
              child: _CategorySectionHeader(
                label: section.$1,
                count: count,
                backgroundColor: cs.surfaceDim,
                foregroundColor: cs.primary,
              ),
            ),
            Skeletonizer.sliver(
              key: i == 0 ? const ValueKey('closet-skeleton') : null,
              enabled: true,
              child: SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  isLast ? bottomPad : 16,
                ),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: _crossAxisCount,
                  mainAxisSpacing: _gridGap,
                  crossAxisSpacing: _gridGap,
                  childCount: count,
                  itemBuilder: (context, index) =>
                      _ClosetSkeletonTile(aspectRatio: ratios[index]),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return slivers;
  }

  List<Widget> _allSlivers(List<ClosetItem> items, double bottomPad) {
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

  List<Widget> _categorySlivers(List<ClosetItem> items, double bottomPad) {
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
              sliver: SliverMasonryGrid.count(
                crossAxisCount: _crossAxisCount,
                mainAxisSpacing: _gridGap,
                crossAxisSpacing: _gridGap,
                childCount: group.length,
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
    this.onTitleLongPress,
  });

  final double minExtent;
  final double maxExtent;
  final double topInset;
  final Color backgroundColor;
  final Color titleColor;
  final Widget toolbar;
  final VoidCallback? onTitleLongPress;

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
                          child: GestureDetector(
                            onLongPress: onTitleLongPress,
                            child: Text(
                              'Your Closet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'ClashDisplay',
                                fontSize:
                                    _ClosetHeaderMetrics.expandedTitleSize,
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

class _ClosetSkeletonTile extends StatelessWidget {
  const _ClosetSkeletonTile({required this.aspectRatio});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(_tileRadius),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ColoredBox(color: cs.primary.withValues(alpha: 0.08)),
      ),
    );
  }
}

class _ClosetItemTile extends StatefulWidget {
  const _ClosetItemTile({required this.item});

  final ClosetItem item;

  @override
  State<_ClosetItemTile> createState() => _ClosetItemTileState();
}

class _ClosetItemTileState extends State<_ClosetItemTile> {
  bool _imageReady = false;

  void _markImageReady() {
    if (_imageReady || !mounted) return;
    setState(() => _imageReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final cs = Theme.of(context).colorScheme;

    return _PressableScale(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_tileRadius),
        child: Stack(
          children: [
            if (!_imageReady)
              AspectRatio(
                aspectRatio: item.aspectRatio,
                child: _tilePlaceholder(item.blurHash),
              ),
            _ClosetTileImage(item: item, onReady: _markImageReady),
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
                  padding: const EdgeInsets.fromLTRB(10, 20, 10, 9),
                  child: Text(
                    item.displayName,
                    maxLines: 1,
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
    );
  }
}

Widget _tilePlaceholder(String? blurHash) {
  if (blurHash != null && blurHash.isNotEmpty) {
    return BlurHash(
      hash: blurHash,
      imageFit: BoxFit.cover,
      duration: Duration.zero,
    );
  }
  return const Skeletonizer.zone(
    child: Bone(width: double.infinity, height: double.infinity),
  );
}

class _ClosetTileImage extends StatelessWidget {
  const _ClosetTileImage({required this.item, required this.onReady});

  final ClosetItem item;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: cs.primary.withValues(alpha: 0.12),
      child: Icon(
        Icons.checkroom_outlined,
        color: cs.primary.withValues(alpha: 0.35),
      ),
    );

    final isolateUrl = item.tileImageUrl;
    if (isolateUrl != null) {
      return Image.network(
        EnvConfig.resolvePlatformUrl(isolateUrl),
        width: double.infinity,
        fit: BoxFit.fitWidth,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => onReady());
          }
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: child,
          );
        },
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onReady());
          return _keyOrPlaceholder(item, placeholder);
        },
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => onReady());
    return _keyOrPlaceholder(item, placeholder);
  }

  Widget _keyOrPlaceholder(ClosetItem item, Widget placeholder) {
    final imageKey = item.imageKey;
    if (imageKey == null) return placeholder;
    return LayoutBuilder(
      builder: (context, constraints) {
        return ImageWithFallback(
          width: constraints.maxWidth,
          height: constraints.hasBoundedHeight && constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : constraints.maxWidth / item.aspectRatio,
          fit: BoxFit.fitWidth,
          remoteImage: RemoteImage(
            url: item.originalImageUrl ?? '',
            key: imageKey,
            blurHash: item.blurHash,
          ),
          fallbackWidget: placeholder,
        );
      },
    );
  }
}
