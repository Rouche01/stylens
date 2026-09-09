import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/core/services/api_service/user_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/api_responses/email_prefs.dart';

class FakeUserApiService extends UserApiService {
  EmailPrefs prefs = EmailPrefs.optedOut;
  bool failUpdate = false;
  int updateCallCount = 0;
  bool? lastMarketingOptIn;

  @override
  Future<ApiResponse<EmailPrefs>> getEmailPrefs() async {
    return ApiResponse.success(prefs);
  }

  @override
  Future<ApiResponse<EmailPrefs>> updateEmailPrefs({
    required bool marketingOptIn,
  }) async {
    updateCallCount += 1;
    lastMarketingOptIn = marketingOptIn;
    if (failUpdate) {
      return ApiResponse.error(
        defaultMessage: 'update failed',
        statusCode: 400,
      );
    }
    prefs = EmailPrefs(
      marketingOptIn: marketingOptIn,
      marketingOptInAt: marketingOptIn ? 100 : prefs.marketingOptInAt,
      marketingUnsubscribedAt: marketingOptIn ? null : 200,
    );
    return ApiResponse.success(prefs);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchEmailPrefs stores camelCase server prefs', () async {
    final api = FakeUserApiService()
      ..prefs = const EmailPrefs(
        marketingOptIn: true,
        marketingOptInAt: 42,
      );
    final manager = UserStateManager(userApiService: api);

    await manager.fetchEmailPrefs();

    expect(manager.emailPrefs?.marketingOptIn, isTrue);
    expect(manager.emailPrefs?.marketingOptInAt, 42);
  });

  test('setMarketingOptIn PATCHes true and keeps server prefs', () async {
    final api = FakeUserApiService();
    final manager = UserStateManager(userApiService: api);

    final ok = await manager.setMarketingOptIn(true);

    expect(ok, isTrue);
    expect(api.updateCallCount, 1);
    expect(api.lastMarketingOptIn, isTrue);
    expect(manager.emailPrefs?.marketingOptIn, isTrue);
    expect(manager.emailPrefs?.marketingOptInAt, 100);
    expect(manager.emailPrefs?.marketingUnsubscribedAt, isNull);
  });

  test('setMarketingOptIn reverts local prefs when PATCH fails', () async {
    final api = FakeUserApiService()..failUpdate = true;
    final manager = UserStateManager(userApiService: api);
    await manager.fetchEmailPrefs();
    expect(manager.emailPrefs?.marketingOptIn, isFalse);

    final ok = await manager.setMarketingOptIn(true);

    expect(ok, isFalse);
    expect(api.updateCallCount, 1);
    expect(manager.emailPrefs?.marketingOptIn, isFalse);
    expect(manager.isUpdatingEmailPrefs, isFalse);
  });
}
