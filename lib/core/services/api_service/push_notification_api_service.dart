import './base_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';

class PushNotificationApiService extends BaseApiService {
  PushNotificationApiService() : super(resourcePath: 'users');

  Future<ApiResponse<void>> upsertToken({
    required String token,
    required String platform,
  }) async {
    return put<void>(
      '/push-token',
      body: {'token': token, 'platform': platform},
      defaultErrorMessage: 'Failed to register push token',
    );
  }

  Future<ApiResponse<void>> deleteToken(String token) async {
    return delete<void>(
      '/push-token/$token',
      defaultErrorMessage: 'Failed to delete push token',
    );
  }
}
