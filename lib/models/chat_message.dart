import 'dart:io';

import 'package:stylens_app/models/remote_image.dart';

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

class ChatMessage {
  final String? text;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;
  final File? imageFile; // Local image file reference
  final RemoteImage? remoteImage; // Remote image object

  ChatMessage({
    this.text,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
    this.imageFile,
    this.remoteImage,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['content'],
      isUser: json['role'] == 'user',
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['created_at']),
      imageFile: null, // Don't load local file from JSON
      remoteImage: json['image_url'] != null
          ? RemoteImage.fromJson({
              'image_url': json['image_url'] ?? '',
              'image_key': json['image_key'] ?? '',
            })
          : null,
      isLoading: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': text,
      'role': isUser ? 'user' : 'system',
      'created_at': timestamp.millisecondsSinceEpoch,
      'image_url': remoteImage?.url,
      'image_key': remoteImage?.key,
      'isLoading': isLoading,
    };
  }
}
