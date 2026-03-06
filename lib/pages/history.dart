import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/models/style_analysis_session.dart';
import 'package:gostylens/pages/style_analysis.dart';
import 'package:gostylens/widgets/style_analysis_session_card.dart';

class HistoryPage extends StatefulWidget {
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StyleAnalysisSessionManager>().fetchSessions();
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

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StyleAnalysisPage()),
    );

    if (mounted) {
      sessionManager.fetchSessions(refresh: true);
    }
  }

  void _showRenameDialog(StyleAnalysisSession session) {
    final controller = TextEditingController(text: session.title);

    // Delay to let the PopupMenu fully dismiss before opening the dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 24),
          actionsPadding: EdgeInsets.only(right: 16, bottom: 8, top: 0),
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          title: Text(
            'Rename Session',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              fontSize: 18,
            ),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter new name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(
                'Rename',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ).then((newName) {
        if (!mounted) return;
        if (newName != null && newName.isNotEmpty && newName != session.title) {
          context.read<StyleAnalysisSessionManager>().renameSession(
            session.id,
            newName,
            onError: (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
                );
              }
            },
          );
        }
      });
    });
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
            icon: Icon(Icons.refresh),
            onPressed: () {
              context.read<StyleAnalysisSessionManager>().fetchSessions(
                refresh: true,
                isFavourite: _selectedFilter == 'Favorites' ? true : null,
              );
            },
            color: Theme.of(context).colorScheme.secondary,
          ),
        ],
      ),
      body: Consumer<StyleAnalysisSessionManager>(
        builder: (context, sessionManager, child) {
          if (sessionManager.isSessionsLoading &&
              sessionManager.sessions.isEmpty) {
            return Center(child: CircularProgressIndicator());
          }

          if (sessionManager.sessionsError != null &&
              sessionManager.sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                        refresh: true,
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
                child: allSessions.isEmpty && !sessionManager.isSessionsLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: _handleScrollNotification,
                        child: RefreshIndicator(
                          onRefresh: () => sessionManager.fetchSessions(
                            refresh: true,
                            isFavourite: _selectedFilter == 'Favorites'
                                ? true
                                : null,
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 8,
                              bottom: 16,
                            ),
                            itemCount:
                                allSessions.length +
                                (sessionManager.isLoadingMoreSessions ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == allSessions.length) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
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
                                session: session,
                                isBusy: isSessionBusy,
                                showFavoriteIndicator:
                                    _selectedFilter != 'Favorites',
                                onTap: () => _openSession(session.id),
                                onFavorite: () {
                                  context
                                      .read<StyleAnalysisSessionManager>()
                                      .toggleFavorite(
                                        session.id,
                                        !session.isFavorite,
                                        onError: (error) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(error),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                      );
                                },
                                onRename: () {
                                  _showRenameDialog(session);
                                },
                                onDelete: () => context
                                    .read<StyleAnalysisSessionManager>()
                                    .deleteSession(session.id),
                              );
                            },
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
}
