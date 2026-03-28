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
  final List<File>? imageFiles; // Local image file references
  final List<RemoteImage>? remoteImages; // Remote image objects

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
    this.imageFiles,
    this.remoteImages,
    this.role = UserRole.user,
  });

  factory StyleAnalysisSessionMessage.fromJson(Map<String, dynamic> json) {
    List<RemoteImage>? remoteImages;

    if (json['images'] != null) {
      remoteImages = (json['images'] as List)
          .map((i) => RemoteImage.fromJson(i as Map<String, dynamic>))
          .toList();
    } else if (json['image_url'] != null) {
      // Backward compatibility for single image field
      remoteImages = [
        RemoteImage(url: json['image_url'] ?? '', key: json['image_key'] ?? ''),
      ];
    }

    return StyleAnalysisSessionMessage(
      text: json['content'],
      role: json['role'] == 'user'
          ? UserRole.user
          : (json['role'] == 'assistant'
                ? UserRole.assistant
                : UserRole.system),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['created_at']),
      imageFiles: null, // Don't load local files from JSON
      remoteImages: remoteImages,
      isLoading: false,
      error: json['response_error'] != null
          ? StyleAnalysisSessionMessageError(message: json['response_error'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': text,
      'role': role.name,
      'created_at': timestamp.millisecondsSinceEpoch,
      'images': remoteImages?.map((i) => i.toJson()).toList(),
      'isLoading': isLoading,
      'response_error': error,
    };
  }
}
