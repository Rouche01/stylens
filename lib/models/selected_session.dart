import 'package:stylens_app/models/chat_message.dart';

class SelectedStyleAnalysisSession {
  final String? sessionId;
  final List<ChatMessage> messages;

  SelectedStyleAnalysisSession({this.sessionId, this.messages = const []});

  factory SelectedStyleAnalysisSession.fromJson(Map<String, dynamic> json) {
    return SelectedStyleAnalysisSession(
      sessionId: json['session_id'] as String?,
      messages:
          (json['messages'] as List<dynamic>?)
              ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'messages': messages.map((e) => e.toJson()).toList(),
  };
}
