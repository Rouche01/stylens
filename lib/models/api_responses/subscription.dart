class Subscription {
  final String id;
  final String userId;
  final String tier;
  final String? provider;
  final String? providerCustomerId;
  final String? providerSubscriptionId;
  final String status;
  final int? currentPeriodEnd;
  final bool hasReachedLimit;
  final SubscriptionLimits? limits;

  const Subscription({
    required this.id,
    required this.userId,
    required this.tier,
    this.provider,
    this.providerCustomerId,
    this.providerSubscriptionId,
    required this.status,
    this.currentPeriodEnd,
    required this.hasReachedLimit,
    this.limits,
  });

  Subscription copyWith({
    String? id,
    String? userId,
    String? tier,
    String? provider,
    String? providerCustomerId,
    String? providerSubscriptionId,
    String? status,
    int? currentPeriodEnd,
    bool? hasReachedLimit,
    SubscriptionLimits? limits,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tier: tier ?? this.tier,
      provider: provider ?? this.provider,
      providerCustomerId: providerCustomerId ?? this.providerCustomerId,
      providerSubscriptionId:
          providerSubscriptionId ?? this.providerSubscriptionId,
      status: status ?? this.status,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      hasReachedLimit: hasReachedLimit ?? this.hasReachedLimit,
      limits: limits ?? this.limits,
    );
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tier: json['tier'] as String,
      provider: json['provider'] as String?,
      providerCustomerId: json['provider_customer_id'] as String?,
      providerSubscriptionId: json['provider_subscription_id'] as String?,
      status: json['status'] as String,
      currentPeriodEnd: json['current_period_end'] as int?,
      hasReachedLimit: json['has_reached_limit'] == 1,
      limits: json['limits'] != null
          ? SubscriptionLimits.fromJson(json['limits'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'tier': tier,
      'provider': provider,
      'provider_customer_id': providerCustomerId,
      'provider_subscription_id': providerSubscriptionId,
      'status': status,
      'current_period_end': currentPeriodEnd,
      'has_reached_limit': hasReachedLimit,
      'limits': limits?.toJson(),
    };
  }

  bool get isFree => tier == 'free';
  bool get isCore =>
      tier == 'core' && (status == 'active' || status == 'cancelled');
}

class SubscriptionLimits {
  final int sessionCountLimit;
  final int messagePerSessionLimit;
  final int imagePerSessionLimit;

  const SubscriptionLimits({
    required this.sessionCountLimit,
    required this.messagePerSessionLimit,
    required this.imagePerSessionLimit,
  });

  factory SubscriptionLimits.fromJson(Map<String, dynamic> json) {
    return SubscriptionLimits(
      sessionCountLimit: (json['session_count_limit'] as num).toInt(),
      messagePerSessionLimit: (json['message_per_session_limit'] as num)
          .toInt(),
      imagePerSessionLimit: (json['image_per_session_limit'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_count_limit': sessionCountLimit,
      'message_per_session_limit': messagePerSessionLimit,
      'image_per_session_limit': imagePerSessionLimit,
    };
  }
}
