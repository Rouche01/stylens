import 'package:gostylens/models/remote_image.dart';

class StyleAnalysisSession {
  final String id;
  final String userId;
  final String title;
  final RemoteImage? remoteImage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // 'active', 'archived', etc.
  final bool isFavorite;

  StyleAnalysisSession({
    required this.id,
    required this.userId,
    required this.title,
    this.remoteImage,
    required this.createdAt,
    required this.updatedAt,
    this.status = 'active',
    this.isFavorite = false,
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
              'image_blur_hash': json['image_blur_hash'],
            })
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at']),
      status: json['status'] ?? 'active',
      isFavorite: json['is_favourite'] == true || json['is_favourite'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'image_url': remoteImage?.url,
      'image_key': remoteImage?.key,
      'image_blur_hash': remoteImage?.blurHash,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'status': status,
      'is_favorite': isFavorite,
    };
  }

  StyleAnalysisSession copyWith({
    String? id,
    String? userId,
    String? title,
    RemoteImage? remoteImage,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    bool? isFavorite,
  }) {
    return StyleAnalysisSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      remoteImage: remoteImage ?? this.remoteImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
