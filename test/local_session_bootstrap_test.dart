import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gostylens/constants/ux_messages.dart';
import 'package:gostylens/core/managers/asset_upload_manager.dart';
import 'package:gostylens/core/managers/style_analysis_session/slices/selected_session_slice.dart';
import 'package:gostylens/core/services/api_service/asset_api_service.dart';
import 'package:gostylens/core/services/api_service/style_analysis_api_service.dart';
import 'package:gostylens/models/action_state.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/api_responses/paginated_response.dart';
import 'package:gostylens/models/api_responses/pagination_info.dart';
import 'package:gostylens/models/app_image.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/models/selected_session.dart';
import 'package:gostylens/models/style_analysis_session.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';

void main() {
  group('SelectedSessionSlice local bootstrap races', () {
    late ActionState<SelectedStyleAnalysisSession> state;
    late SelectedSessionSlice slice;

    AppImage outfitImage() => AppImage(
      remoteImage: RemoteImage(
        url: 'https://example.com/outfit.jpg',
        key: 'outfit.jpg',
      ),
    );

    List<String?> assistantTexts() => slice.messages
        .where((m) => !m.isUserMessage && !m.isLoading)
        .map((m) => m.text)
        .toList();

    int initialOutfitCount() => slice.messages
        .where(
          (m) =>
              m.isUserMessage &&
              (m.images?.isNotEmpty ?? false) &&
              m.text == UxMessages.initialOutfitPromptTextAugmentation,
        )
        .length;

    setUp(() {
      final getIt = GetIt.instance;
      if (!getIt.isRegistered<AssetApiService>()) {
        getIt.registerSingleton<AssetApiService>(AssetApiService());
      }
      if (!getIt.isRegistered<AssetUploadManager>()) {
        getIt.registerSingleton<AssetUploadManager>(AssetUploadManager());
      }

      state = ActionState<SelectedStyleAnalysisSession>.initial();
      slice = SelectedSessionSlice(
        apiService: _NoopStyleAnalysisApiService(),
        assetApiService: getIt<AssetApiService>(),
        assetUploadManager: getIt<AssetUploadManager>(),
        getState: () => state,
        setState: (newState) => state = newState,
        notifyListeners: () {},
      );
    });

    tearDown(() {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<AssetApiService>()) {
        getIt.unregister<AssetApiService>();
      }
      if (getIt.isRegistered<AssetUploadManager>()) {
        getIt.unregister<AssetUploadManager>();
      }
    });

    test(
      'empty intro mid-delay then outfit start leaves only outfit messages',
      () {
        fakeAsync((async) {
          slice.prepareEmptySession();
          var emptyDone = false;
          slice.playPendingLocalIntro().then((_) => emptyDone = true);

          // Pause during the first empty-session typing delay.
          async.elapse(const Duration(milliseconds: 500));

          slice.prepareOutfitSession([outfitImage()]);
          var outfitDone = false;
          slice.playPendingLocalIntro().then((_) => outfitDone = true);

          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();

          expect(emptyDone, isTrue);
          expect(outfitDone, isTrue);

          final texts = assistantTexts();
          expect(
            texts,
            isNot(contains(UxMessages.initialStylistReplyWithoutImage1)),
          );
          expect(
            texts,
            isNot(contains(UxMessages.initialStylistReplyWithoutImage2)),
          );
          expect(texts, contains(UxMessages.initialStylistReplyWithImage));

          expect(
            slice.messages.any(
              (m) =>
                  m.isUserMessage &&
                  (m.images?.isNotEmpty ?? false) &&
                  m.text == UxMessages.initialOutfitPromptTextAugmentation,
            ),
            isTrue,
          );
        });
      },
    );

    test('releaseActiveSession mid empty intro adds no further messages', () {
      fakeAsync((async) {
        slice.prepareEmptySession();
        var playDone = false;
        slice.playPendingLocalIntro().then((_) => playDone = true);

        async.elapse(const Duration(milliseconds: 500));
        expect(slice.messages.any((m) => m.isLoading), isTrue);

        slice.releaseActiveSession();
        expect(slice.sessionId, isNull);
        expect(slice.messages, isEmpty);

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(playDone, isTrue);
        expect(slice.messages, isEmpty);
        expect(assistantTexts(), isEmpty);
      });
    });

    test(
      'releaseActiveSession mid outfit stylist delay leaves no leftover bot line',
      () {
        fakeAsync((async) {
          slice.prepareOutfitSession([outfitImage()]);
          var playDone = false;
          slice.playPendingLocalIntro().then((_) => playDone = true);

          // Asset prep is sync when remoteImage is already set; stylist delay is 1.5s.
          async.elapse(const Duration(milliseconds: 200));
          expect(slice.messages.any((m) => m.isUserMessage), isTrue);

          slice.releaseActiveSession();
          expect(slice.messages, isEmpty);

          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();

          expect(playDone, isTrue);
          expect(slice.messages, isEmpty);
          expect(
            assistantTexts(),
            isNot(contains(UxMessages.initialStylistReplyWithImage)),
          );
        });
      },
    );

    test(
      'submitInitialOutfit does not stack when outfit text is not the default prompt',
      () {
        fakeAsync((async) {
          slice.addMessage(
            UserRole.user,
            images: [outfitImage()],
            text: 'Does this work for a wedding?',
          );

          slice.submitInitialOutfit([outfitImage()]);

          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();

          expect(
            slice.messages
                .where((m) => m.isUserMessage && (m.images?.isNotEmpty ?? false))
                .length,
            1,
          );
        });
      },
    );

    test('submitInitialOutfit twice does not stack another outfit message', () {
      fakeAsync((async) {
        slice.submitInitialOutfit([outfitImage()]);
        slice.submitInitialOutfit([outfitImage()]);

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(initialOutfitCount(), 1);
        expect(
          assistantTexts()
              .where((t) => t == UxMessages.initialStylistReplyWithImage)
              .length,
          1,
        );
      });
    });

    test(
      'prepareOutfitSession then submitInitialOutfit keeps a single outfit',
      () {
        fakeAsync((async) {
          slice.prepareOutfitSession([outfitImage()]);
          slice.playPendingLocalIntro();
          async.elapse(const Duration(milliseconds: 200));

          slice.submitInitialOutfit([outfitImage()]);

          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();

          expect(initialOutfitCount(), 1);
        });
      },
    );
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
