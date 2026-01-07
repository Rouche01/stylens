import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stylens_app/core/managers/style_analysis_session/index.dart';
import 'package:stylens_app/pages/style_analysis.dart';
import 'package:stylens_app/widgets/style_analysis_session_card.dart';

class HistoryPage extends StatefulWidget {
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'History',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'ClashDisplay',
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              context.read<StyleAnalysisSessionManager>().fetchSessions(
                refresh: true,
              );
            },
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
                      sessionManager.fetchSessions(refresh: true);
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (sessionManager.sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No style sessions yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start by capturing an outfit!',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final itemCount =
              sessionManager.sessions.length +
              (sessionManager.isLoadingMoreSessions ? 1 : 0);

          return NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: RefreshIndicator(
              onRefresh: () => sessionManager.fetchSessions(refresh: true),
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (index == sessionManager.sessions.length) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  final session = sessionManager.sessions[index];
                  final isSessionBusy = sessionManager.isSessionBusy(
                    session.id,
                  );

                  return SessionCard(
                    session: session,
                    isBusy: isSessionBusy,
                    onTap: () => _openSession(session.id),
                    onDelete: () => context
                        .read<StyleAnalysisSessionManager>()
                        .deleteSession(session.id),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
