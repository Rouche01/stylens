import 'package:gostylens/models/api_responses/gender.dart';
import 'package:gostylens/models/api_responses/subscription.dart';

class User {
  final String id;
  final String authId;
  final String name;
  final String? nickname;
  final Gender? gender;
  final String? email;
  final int createdAt;
  final int updatedAt;
  final bool isActive;
  final Subscription subscription;

  const User({
    required this.id,
    required this.authId,
    required this.name,
    this.nickname,
    this.gender,
    this.email,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
    required this.subscription,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      authId: json['auth_id'] as String,
      name: json['name'] as String,
      nickname: json['nickname'] as String?,
      gender: json['gender'] != null
          ? Gender.fromValue(json['gender'] as String)
          : null,
      email: json['email'] as String?,
      createdAt: json['created_at'] as int,
      updatedAt: json['updated_at'] as int,
      isActive: json['is_active'] == 1,
      subscription: Subscription.fromJson(
        json['subscription'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_id': authId,
      'name': name,
      if (nickname != null) 'nickname': nickname,
      if (gender != null) 'gender': gender!.value,
      if (email != null) 'email': email,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_active': isActive,
      'subscription': subscription.toJson(),
    };
  }

  User copyWith({
    String? id,
    String? authId,
    String? name,
    String? nickname,
    Gender? gender,
    String? email,
    int? createdAt,
    int? updatedAt,
    int? isActive,
    Subscription? subscription,
  }) {
    return User(
      id: id ?? this.id,
      authId: authId ?? this.authId,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      gender: gender ?? this.gender,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: this.isActive,
      subscription: subscription ?? this.subscription,
    );
  }
}
