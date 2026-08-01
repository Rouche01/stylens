import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/constants/loading_transitions.dart';
import 'package:gostylens/models/style_analysis_session.dart';
import 'package:gostylens/utils/style_analysis_actions.dart';
import 'package:provider/provider.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/navigation/app_routes.dart';
import 'package:gostylens/widgets/floating_nav_bar.dart';
import 'package:gostylens/widgets/style_analysis_session_card.dart';
import 'package:skeletonizer/skeletonizer.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with StyleAnalysisActions {
  static const int _skeletonCardCount = 7;

  String _selectedFilter = 'All';

  /// True until the first sessions fetch finishes — avoids empty-state flash
  /// before [isSessionsLoading] becomes true.
  bool _awaitingInitialSessions = true;

  static List<StyleAnalysisSession> get _placeholderSessions {
    final now = DateTime.now();
    return List.generate(
      _skeletonCardCount,
      (index) => StyleAnalysisSession(
        id: 'skeleton-$index',
        userId: '',
        title: 'Loading session title placeholder',
        createdAt: now,
        updatedAt: now.subtract(Duration(minutes: index + 1)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Start sync so loading is set before the first Consumer build when possible.
    context
        .read<StyleAnalysisSessionManager>()
        .fetchSessions()
        .whenComplete(() {
          if (mounted) setState(() => _awaitingInitialSessions = false);
        });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification ||
        notification is ScrollUpdateNotification) {
      final metrics = notification.metrics;
      final isNearBottom = metrics.pixels >= metrics.maxScrollExtent - 200;

      if (isNearBottom) {
        final sessionManager = context.read<StyleAnalysisSessionManager>();
        if (!sessionManager.isLoadingMoreSessions &&
            sessionManager.hasMoreSessions) {
          sessionManager.loadMoreSessions();
        }
      }
    }
    return false;
  }

  Future<void> _openSession(String sessionId) async {
    final sessionManager = context.read<StyleAnalysisSessionManager>();

    sessionManager.setSelectedSessionId(sessionId);

    final stale = await context.push<bool>(AppRoutes.session(sessionId));

    if (mounted && (stale == true || sessionManager.sessionsListStale)) {
      sessionManager.consumeSessionsListStale();
      await sessionManager.refreshSessionsPreservingPagination(silent: true);
    }
  }

  Widget _buildFilterPill(String title) {
    final isSelected = _selectedFilter == title;
    return InkWell(
      onTap: () {
        if (_selectedFilter != title) {
          setState(() {
            _selectedFilter = title;
          });
          context.read<StyleAnalysisSessionManager>().fetchSessions(
            isFavourite: title == 'Favorites' ? true : null,
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.tertiary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            width: 0,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.tertiary
                : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// Bottom padding so list / empty states clear the floating dock.
  double get _listBottomPadding =>
      16 + FloatingNavBar.contentBottomInset(context);

  /// Centers [child] in the visible area above the floating dock.
  Widget _dockAwareCenter({required Widget child}) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: FloatingNavBar.contentBottomInset(context),
      ),
      child: Center(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'History',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'ClashDisplay',
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 24),
            onPressed: () {
              context.read<StyleAnalysisSessionManager>().fetchSessions(
                forceRefresh: true,
                isFavourite: _selectedFilter == 'Favorites' ? true : null,
              );
            },
            color: Theme.of(context).colorScheme.secondary,
          ),
        ],
      ),
      body: Consumer<StyleAnalysisSessionManager>(
        builder: (context, sessionManager, child) {
          if (sessionManager.sessionsError != null &&
              sessionManager.sessions.isEmpty &&
              !sessionManager.isSessionsLoading) {
            return _dockAwareCenter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    sessionManager.sessionsError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      sessionManager.fetchSessions(
                        forceRefresh: true,
                        isFavourite: _selectedFilter == 'Favorites'
                            ? true
                            : null,
                      );
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final allSessions = sessionManager.sessions;
          final wantsSkeleton =
              allSessions.isEmpty &&
              (sessionManager.isSessionsLoading || _awaitingInitialSessions);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Filters row
              Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    _buildFilterPill('All'),
                    SizedBox(width: 8),
                    _buildFilterPill('Favorites'),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: AnimatedSwitcher(
                  duration: LoadingTransitions.duration,
                  switchInCurve: LoadingTransitions.switchInCurve,
                  switchOutCurve: LoadingTransitions.switchOutCurve,
                  child: wantsSkeleton
                      ? KeyedSubtree(
                          key: const ValueKey('history-skeleton'),
                          child: _buildSkeletonList(),
                        )
                      : allSessions.isEmpty
                      ? KeyedSubtree(
                          key: const ValueKey('history-empty'),
                          child: _dockAwareCenter(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _selectedFilter == 'All'
                                      ? Icons.history
                                      : Icons.favorite_border,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  _selectedFilter == 'All'
                                      ? 'No style sessions yet'
                                      : 'No favorites yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (_selectedFilter == 'All') ...[
                                  SizedBox(height: 8),
                                  Text(
                                    'Start by capturing an outfit!',
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('history-list'),
                          child: NotificationListener<ScrollNotification>(
                            onNotification: _handleScrollNotification,
                            child: RefreshIndicator(
                              onRefresh: () => sessionManager.fetchSessions(
                                forceRefresh: true,
                                isFavourite: _selectedFilter == 'Favorites'
                                    ? true
                                    : null,
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: 8,
                                  bottom: _listBottomPadding,
                                ),
                                itemCount:
                                    allSessions.length +
                                    (sessionManager.isLoadingMoreSessions
                                        ? 1
                                        : 0),
                                itemBuilder: (context, index) {
                                  if (index == allSessions.length) {
                                    return Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final session = allSessions[index];
                                  final isSessionBusy = sessionManager
                                      .isSessionBusy(session.id);

                                  return SessionCard(
                                    key: ValueKey(session.id),
                                    session: session,
                                    isBusy: isSessionBusy,
                                    showFavoriteIndicator:
                                        _selectedFilter != 'Favorites',
                                    onTap: () => _openSession(session.id),
                                    onDelete: () => sessionManager
                                        .deleteSession(session.id),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSkeletonList() {
    final placeholders = _placeholderSessions;
    return Skeletonizer(
      enabled: true,
      child: IgnorePointer(
        child: ListView.builder(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: _listBottomPadding,
          ),
          itemCount: placeholders.length,
          itemBuilder: (context, index) {
            final session = placeholders[index];
            return SessionCard(
              key: ValueKey(session.id),
              session: session,
              showFavoriteIndicator: _selectedFilter != 'Favorites',
              onTap: () {},
              onDelete: () {},
            );
          },
        ),
      ),
    );
  }
}
