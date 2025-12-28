import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_env_config/flutter_env_config.dart';
import 'package:stylens_app/models/chat_message.dart';
import 'package:stylens_app/models/style_analysis_session.dart';

enum ContextMode { recent, all, last }

class StyleAnalysisSessionManager extends ChangeNotifier {
  // Store list of sessions
  List<StyleAnalysisSession> _sessions = [];
  bool _isLoading = false;
  String? _error;

  // Store messages for the selected session
  String? _selectedSessionId;
  List<ChatMessage> _selectedSessionMessages = [];
  bool _isLoadingMessages = false;

  // Temporary user ID - replace with actual auth later
  static const String tempUserId = 'day2TestId5';

  List<StyleAnalysisSession> get sessions => List.unmodifiable(_sessions);
  bool get isLoading => _isLoading;
  String? get error => _error;

  String? get selectedSessionId => _selectedSessionId;
  List<ChatMessage> get selectedSessionMessages =>
      List.unmodifiable(_selectedSessionMessages);
  bool get isLoadingMessages => _isLoadingMessages;

  final EnvironmentConfig _config = EnvironmentManager.environmentData;

  Future<void> streamAssistantResponse(
    String sessionId, {
    ContextMode contextMode = ContextMode.recent,
  }) async {
    try {
      print('Starting AI response stream for session: $sessionId');

      final request = http.Request(
        'GET',
        Uri.parse(
          '${_config.api?.baseUrl}/style-analysis/sessions/$sessionId/stream?userId=$tempUserId&contextMode=${contextMode.name}',
        ),
      );

      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';

      print('Request URL: ${request.url}');
      print('Request headers: ${request.headers}');

      final streamedResponse = await request.send();

      print('Response status code: ${streamedResponse.statusCode}');
      print('Response headers: ${streamedResponse.headers}');

      if (streamedResponse.statusCode == 200) {
        String buffer = '';
        int chunkCount = 0;

        await for (var chunk in streamedResponse.stream.transform(
          utf8.decoder,
        )) {
          chunkCount++;
          print('Received chunk #$chunkCount: $chunk');
          buffer += chunk;

          // Process complete lines (SSE events end with \n\n)
          while (buffer.contains('\n\n')) {
            final endIndex = buffer.indexOf('\n\n');
            final event = buffer.substring(0, endIndex);
            buffer = buffer.substring(endIndex + 2);

            print('Processing event: $event');

            // Parse SSE event
            if (event.startsWith('data: ')) {
              final data = event.substring(6); // Remove 'data: ' prefix
              print('Extracted data: $data');

              if (data == '[DONE]') {
                print('Stream completed');
                break;
              }

              try {
                final jsonData = json.decode(data);

                // Handle the streamed chunk
                // Example: {"content": "partial text...", "done": false}
                print('Received chunk: $jsonData');

                // TODO: Update UI with streaming text
                // You might want to accumulate chunks and update a message in real-time
              } catch (e) {
                print('Error parsing chunk: $e');
              }
            }
          }
        }

        print('Stream finished');
      } else {
        _error = 'Failed to get AI response: ${streamedResponse.statusCode}';
        print(_error);
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to stream AI response: $e';
      print('Error streaming AI response: $e');
      notifyListeners();
    }
  }

  // Create a new session
  Future<String?> createSession({
    required List<ChatMessage> messages,
    String? title,
  }) async {
    try {
      print('Creating new style analysis session');

      // Convert ChatMessage list to MessageEntry format
      final messageEntries = messages.map((msg) {
        return {
          'role': msg.isUser ? 'user' : 'system',
          'prompt': msg.text,
          'remoteImage': msg.remoteImage != null
              ? {'url': msg.remoteImage!.url, 'key': msg.remoteImage!.key}
              : null,
        };
      }).toList();

      print('Message entries: $messageEntries');

      final requestBody = {'userId': tempUserId, 'messages': messageEntries};

      final response = await http.post(
        Uri.parse('${_config.api?.baseUrl}/style-analysis/sessions'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final sessionId = responseData['sessionId'] ?? responseData['id'];
        print('Session created successfully: $sessionId');

        // Make request to streaming endpoint with sessionId to get AI response
        streamAssistantResponse(sessionId, contextMode: ContextMode.all);

        // Optionally refresh sessions list
        await fetchSessions();

        return sessionId;
      } else {
        _error =
            'Failed to create session: ${response.statusCode} - ${response.body}';
        print(_error);
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = 'Failed to create session: $e';
      print('Error creating session: $e');
      notifyListeners();
      return null;
    }
  }

  // Fetch sessions from API
  Future<void> fetchSessions() async {
    _setLoading(true);
    _error = null;

    print('Fetching style analysis sessions for userId: $tempUserId');

    try {
      final response = await http.get(
        Uri.parse(
          '${_config.api?.baseUrl}/style-analysis/sessions?userId=$tempUserId',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> sessionsJson = json.decode(
          response.body,
        )['sessions'];
        print('all sessions $sessionsJson');
        _sessions = sessionsJson
            .map((json) => StyleAnalysisSession.fromJson(json))
            .toList();

        // Sort by most recent first
        _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      } else {
        _error = 'Failed to load sessions: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Network error: $e';
    } finally {
      _setLoading(false);
    }
  }

  // Fetch messages for a specific session
  Future<bool> fetchSessionMessages(String sessionId) async {
    _isLoadingMessages = true;
    _error = null;
    notifyListeners();

    print('Fetching messages for session: $sessionId');

    try {
      final response = await http.get(
        Uri.parse(
          '${_config.api?.baseUrl}/style-analysis/sessions/$sessionId/messages?userId=$tempUserId',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Response data: $responseData');
        final List<dynamic> messagesJson = responseData['messages'] ?? [];
        print('Messages JSON: $messagesJson');

        _selectedSessionId = sessionId;
        _selectedSessionMessages = messagesJson
            .map((json) => ChatMessage.fromJson(json))
            .toList();

        print('Loaded ${_selectedSessionMessages.length} messages');
        _isLoadingMessages = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to load messages: ${response.statusCode}';
        _isLoadingMessages = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to fetch messages: $e';
      _isLoadingMessages = false;
      notifyListeners();
      return false;
    }
  }

  // Clear current session data
  void clearCurrentSession() {
    _selectedSessionId = null;
    _selectedSessionMessages = [];
    notifyListeners();
  }

  // Delete session
  Future<bool> deleteSession(String sessionId) async {
    try {
      print('Deleting session: $sessionId');

      final response = await http.delete(
        Uri.parse(
          '${_config.api?.baseUrl}/style-analysis/sessions/$sessionId?userId=$tempUserId',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Remove from local list
        _sessions.removeWhere((s) => s.id == sessionId);
        notifyListeners();
        print('Session deleted successfully');
        return true;
      } else {
        _error = 'Failed to delete session: ${response.statusCode}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to delete session: $e';
      notifyListeners();
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
