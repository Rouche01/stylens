import './base_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/api_responses/subscription.dart';

class SubscriptionApiService extends BaseApiService {
  SubscriptionApiService() : super(resourcePath: 'subscriptions');

  /// Fetches a subscription by the internal User ID.
  Future<ApiResponse<Subscription>> getSubscriptionByUserId(
    String userId,
  ) async {
    return get<Subscription>(
      '/$userId',
      fromJson: (data) => Subscription.fromJson(data),
      defaultErrorMessage: 'Subscription not found or error occurred',
    );
  }

  /// Updates a subscription with RevenueCat provider data.
  Future<ApiResponse<Subscription>> updateSubscription(
    String userId, {
    required Map<String, dynamic> body,
  }) async {
    return patch<Subscription>(
      '/$userId',
      body: body,
      fromJson: (data) => Subscription.fromJson(data),
      defaultErrorMessage: 'Failed to update subscription',
    );
  }
}
