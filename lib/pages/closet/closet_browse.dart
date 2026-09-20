import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/core/managers/closet_manager.dart';
import 'package:gostylens/models/closet_item.dart';
import 'package:gostylens/navigation/app_routes.dart';
import 'package:gostylens/pages/closet/closet_ask_banner.dart';
import 'package:gostylens/pages/closet/closet_ask_sheet.dart';
import 'package:gostylens/pages/closet/closet_browse_layout.dart';
import 'package:gostylens/pages/closet/closet_empty.dart';
import 'package:gostylens/pages/closet/closet_grid.dart';
import 'package:gostylens/pages/closet/closet_header.dart';
import 'package:gostylens/widgets/floating_nav_bar.dart';
import 'package:provider/provider.dart';

class ClosetBrowseView extends StatefulWidget {
  const ClosetBrowseView({super.key});

  /// Trailing scroll extent after the grid so the last tile can rest above
  /// the dock. The scroll view stays full-bleed so the bar does not sit on
  /// a mint band of empty scaffold.
  static const scrollBottomInsetKey = ValueKey('closet-scroll-bottom-inset');

  @override
  State<ClosetBrowseView> createState() => _ClosetBrowseViewState();
}

class _ClosetBrowseViewState extends State<ClosetBrowseView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();
  ClosetViewMode _viewMode = ClosetViewMode.categories;
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

  void _onViewModeChanged(ClosetViewMode mode) {
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
    final range = ClosetHeaderMetrics.collapseRange(
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
    return items.where((item) => closetItemMatchesQuery(item, query)).toList();
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

  void _openAskSheet() {
    _dismissKeyboard();
    final manager = context.read<ClosetManager>();
    final ask = manager.currentAsk;
    if (ask == null) return;
    unawaited(ClosetAskSheet.show(context, manager: manager, ask: ask));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dockReserve = math.max(
      MediaQuery.paddingOf(context).bottom,
      FloatingNavBar.contentBottomInset(context),
    );

    final topInset = MediaQuery.paddingOf(context).top;
    final minHeader = ClosetHeaderMetrics.minExtentFor(topInset);
    final maxHeader = ClosetHeaderMetrics.maxExtentFor(topInset);

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
              16 +
              dockReserve +
              (showChip ? ClosetProcessingDockChip.scrollReserve(context) : 0);

          final emptyKind = processingEmpty
              ? ClosetEmptyKind.processing
              : failedEmpty
              ? ClosetEmptyKind.failed
              : ClosetEmptyKind.idle;

          // All is a compact masonry (no section headers), so a small closet
          // often fits in the viewport. Default physics then refuse drags and
          // RefreshIndicator never fires. AlwaysScrollable keeps pull-to-refresh
          // working for short All grids and empty states.
          final physics = showSkeleton
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics();

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
                    scrollCacheExtent: const ScrollCacheExtent.viewport(0.5),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverResizingHeader(
                        minExtentPrototype: SizedBox(height: minHeader),
                        maxExtentPrototype: SizedBox(height: maxHeader),
                        child: ClosetBrowseHeader(
                          minExtent: minHeader,
                          maxExtent: maxHeader,
                          topInset: topInset,
                          backgroundColor: cs.surfaceDim,
                          titleColor: cs.primary,
                          toolbar: ClosetBrowseToolbar(
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
                      ...closetBrowseBodySlivers(
                        context: context,
                        viewMode: _viewMode,
                        items: items,
                        bottomPad: bottomPad,
                        showSkeleton: showSkeleton,
                        catalogEmpty: catalogEmpty,
                        processingEmpty: processingEmpty,
                        failedEmpty: failedEmpty,
                        hasAskChrome:
                            manager.askSettle != null ||
                            manager.currentAsk != null,
                        emptyKind: emptyKind,
                        errorMessage: manager.error,
                        query: query,
                        dockInsetKey: ClosetBrowseView.scrollBottomInsetKey,
                        onRetry: _refresh,
                        onClearSearch: _searchController.clear,
                        onCapture: _openCapture,
                      ),
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
}
