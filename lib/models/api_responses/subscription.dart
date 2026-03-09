class Subscription {
  final String id;
  final String userId;
  final String tier;
  final String? provider;
  final String? providerCustomerId;
  final String? providerSubscriptionId;
  final String status;
  final int? currentPeriodEnd;

  const Subscription({
    required this.id,
    required this.userId,
    required this.tier,
    this.provider,
    this.providerCustomerId,
    this.providerSubscriptionId,
    required this.status,
    this.currentPeriodEnd,
  });

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
    };
  }

  bool get isFree => tier == 'free';
  bool get isCore => tier == 'core';
}
