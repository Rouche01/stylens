import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gostylens/core/managers/asset_upload_manager.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/core/services/api_service/asset_api_service.dart';
import 'package:gostylens/core/services/api_service/style_analysis_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/api_responses/paginated_response.dart';
import 'package:gostylens/models/api_responses/pagination_info.dart';
import 'package:gostylens/models/style_analysis_session.dart';

void main() {
  group('StyleAnalysisSessionManager sessionsListStale', () {
    late StyleAnalysisSessionManager manager;

    setUp(() {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<StyleAnalysisApiService>()) {
        getIt.unregister<StyleAnalysisApiService>();
      }
      if (getIt.isRegistered<AssetApiService>()) {
        getIt.unregister<AssetApiService>();
      }
      if (getIt.isRegistered<AssetUploadManager>()) {
        getIt.unregister<AssetUploadManager>();
      }

      getIt.registerSingleton<StyleAnalysisApiService>(
        _NoopStyleAnalysisApiService(),
      );
      getIt.registerSingleton<AssetApiService>(AssetApiService());
      getIt.registerSingleton<AssetUploadManager>(AssetUploadManager());

      manager = StyleAnalysisSessionManager();
    });

    tearDown(() {
      manager.dispose();
      final getIt = GetIt.instance;
      if (getIt.isRegistered<StyleAnalysisApiService>()) {
        getIt.unregister<StyleAnalysisApiService>();
      }
      if (getIt.isRegistered<AssetApiService>()) {
        getIt.unregister<AssetApiService>();
      }
      if (getIt.isRegistered<AssetUploadManager>()) {
        getIt.unregister<AssetUploadManager>();
      }
    });

    test('consumeSessionsListStale returns true once then false', () {
      expect(manager.sessionsListStale, isFalse);
      expect(manager.consumeSessionsListStale(), isFalse);

      manager.markSessionsListStale();
      expect(manager.sessionsListStale, isTrue);
      expect(manager.consumeSessionsListStale(), isTrue);
      expect(manager.sessionsListStale, isFalse);
      expect(manager.consumeSessionsListStale(), isFalse);
    });
  });
}

class _NoopStyleAnalysisApiService extends StyleAnalysisApiService {
  @override
  Future<ApiResponse<PaginatedResponse<StyleAnalysisSession>>> fetchSessions({
    int page = 1,
    int pageSize = 10,
    bool? isFavourite,
    bool forceRefresh = false,
  }) async {
    return ApiResponse.success(
      PaginatedResponse(
        items: const [],
        pagination: PaginationInfo(
          page: 1,
          pageSize: 10,
          totalItems: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false,
        ),
      ),
    );
  }
}
