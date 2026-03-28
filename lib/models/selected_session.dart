import 'package:gostylens/models/style_analysis_session_message.dart';

class SelectedStyleAnalysisSession {
  final String? sessionId;
  final List<StyleAnalysisSessionMessage> messages;

  SelectedStyleAnalysisSession({this.sessionId, this.messages = const []});

  factory SelectedStyleAnalysisSession.fromJson(Map<String, dynamic> json) {
    return SelectedStyleAnalysisSession(
      sessionId: json['session_id'] as String?,
      messages:
          (json['messages'] as List<dynamic>?)
              ?.map(
                (e) => StyleAnalysisSessionMessage.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'messages': messages.map((e) => e.toJson()).toList(),
  };

  SelectedStyleAnalysisSession copyWith({
    String? sessionId,
    List<StyleAnalysisSessionMessage>? messages,
  }) {
    return SelectedStyleAnalysisSession(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
    );
  }
}
