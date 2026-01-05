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
    // Load sessions when page initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StyleAnalysisSessionManager>().fetchSessions();
    });
  }

  Future<void> _openSession(String sessionId) async {
    final sessionManager = context.read<StyleAnalysisSessionManager>();

    sessionManager.setSelectedSessionId(sessionId);

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StyleAnalysisPage()),
    );

    // Refresh sessions when returning from style analysis page
    if (mounted) {
      sessionManager.fetchSessions();
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
              context.read<StyleAnalysisSessionManager>().fetchSessions();
            },
          ),
        ],
      ),
      body: Consumer<StyleAnalysisSessionManager>(
        builder: (context, sessionManager, child) {
          if (sessionManager.isSessionsLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (sessionManager.sessionsError != null) {
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
                      sessionManager.fetchSessions();
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

          return RefreshIndicator(
            onRefresh: () => sessionManager.fetchSessions(),
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: sessionManager.sessions.length,
              itemBuilder: (context, index) {
                final session = sessionManager.sessions[index];
                final isSessionBusy = sessionManager.isSessionBusy(session.id);

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
          );
        },
      ),
    );
  }
}
