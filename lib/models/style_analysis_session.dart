import 'package:stylens_app/models/remote_image.dart';

class StyleAnalysisSession {
  final String id;
  final String userId;
  final String title;
  final RemoteImage? remoteImage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // 'active', 'archived', etc.

  StyleAnalysisSession({
    required this.id,
    required this.userId,
    required this.title,
    this.remoteImage,
    required this.createdAt,
    required this.updatedAt,
    this.status = 'active',
  });

  factory StyleAnalysisSession.fromJson(Map<String, dynamic> json) {
    return StyleAnalysisSession(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      remoteImage: json['image_url'] != null
          ? RemoteImage.fromJson({
              'image_url': json['image_url'] ?? '',
              'image_key': json['image_key'] ?? '',
            })
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at']),
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'image_url': remoteImage?.url,
      'image_key': remoteImage?.key,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'status': status,
    };
  }

  StyleAnalysisSession copyWith({
    String? id,
    String? userId,
    String? title,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return StyleAnalysisSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      remoteImage: remoteImage ?? this.remoteImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }
}
