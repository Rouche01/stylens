import 'dart:io';

import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/models/style_analysis_session_message_error.dart';

// [
//   {
//     id: "a9cf1ffb-b6b2-42f5-b944-c7721bf7b587",
//     style_analysis_history_id: "8f30b303-d1ac-4976-82ec-cc4c91dc630c",
//     role: "user",
//     content: "What do you think about my outfit?",
//     image_url: null,
//     created_at: 1761472118591
//   },
// ]

enum UserRole { user, assistant, system }

class StyleAnalysisSessionMessage {
  final String? text;
  final UserRole role;
  final DateTime timestamp;
  final bool isLoading;
  final StyleAnalysisSessionMessageError? error;
  final File? imageFile; // Local image file reference
  final RemoteImage? remoteImage; // Remote image object

  bool get isUserMessage => role == UserRole.user;
  bool get isAssistantMessage => role == UserRole.assistant;
  bool get isSystemMessage => role == UserRole.system;
  bool get isError => error != null;

  String? get displayText => error != null ? error?.message : text;

  StyleAnalysisSessionMessage({
    this.text,
    required this.timestamp,
    this.isLoading = false,
    this.error,
    this.imageFile,
    this.remoteImage,
    this.role = UserRole.user,
  });

  factory StyleAnalysisSessionMessage.fromJson(Map<String, dynamic> json) {
    return StyleAnalysisSessionMessage(
      text: json['content'],
      role: json['role'] == 'user'
          ? UserRole.user
          : (json['role'] == 'assistant'
                ? UserRole.assistant
                : UserRole.system),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['created_at']),
      imageFile: null, // Don't load local file from JSON
      remoteImage: json['image_url'] != null
          ? RemoteImage.fromJson({
              'image_url': json['image_url'] ?? '',
              'image_key': json['image_key'] ?? '',
            })
          : null,
      isLoading: false,
      error: json['response_error'] != null
          ? StyleAnalysisSessionMessageError(message: json['responseError'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': text,
      'role': role,
      'created_at': timestamp.millisecondsSinceEpoch,
      'image_url': remoteImage?.url,
      'image_key': remoteImage?.key,
      'isLoading': isLoading,
      'response_error': error,
    };
  }
}
