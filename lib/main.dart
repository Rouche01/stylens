import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostylens/core/services/analytics_service.dart';
import 'package:gostylens/core/managers/auth_state_manager.dart';
import 'package:provider/provider.dart';
import 'package:gostylens/navigation/app_router.dart';
import 'package:gostylens/navigation/auth_flow_controller.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'core/managers/style_analysis_session/index.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:gostylens/core/managers/global_loader/global_loader_scope.dart';
import 'package:lottie/lottie.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:gostylens/core/managers/asset_upload_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:gostylens/core/managers/push_notification_manager.dart';
import 'package:gostylens/core/navigation/app_navigation_keys.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_service.dart';

const _splashRevealAsset = 'assets/animations/gostylens-logo-reveal-v2.json';

/// Hard ceiling for pre-[runApp] work. Native splash is preserved until
/// [AuthLoadingScreen] paints; without a timeout a hung plugin init looks like
/// a permanent splash freeze on Play Store installs.
const _bootstrapTimeout = Duration(seconds: 25);

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    final authController = await _bootstrap().timeout(_bootstrapTimeout);
    runApp(MyApp(authController: authController));
  } on TimeoutException {
    FlutterNativeSplash.remove();
    runApp(
      const ErrorApp(
        errorMessage:
            'Startup timed out while initializing (Firebase / Sign-In / '
            'analytics). Pull-to-refresh is not available — force-quit and '
            'reopen, or install a newer build.',
      ),
    );
  } catch (e) {
    FlutterNativeSplash.remove();
    runApp(ErrorApp(errorMessage: e.toString()));
  }
}

Future<AuthFlowController> _bootstrap() async {
  // Warm up the SharedPreferences Pigeon channel before any plugin uses it.
  // On release builds, PostHog/Supabase call shared_preferences internally
  // during init — if the channel isn't established first, it throws a
  // PlatformException(channel-error) and crashes the app.
  await SharedPreferences.getInstance();

  const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  await dotenv.load(fileName: ".env.$environment");
  EnvConfig.init();

  // Initialize Firebase
  await Firebase.initializeApp();
  registerFirebaseMessagingBackgroundHandler();

  // Set up singleton services
  await setupLocator();

  LottieComposition? splashComposition;
  try {
    splashComposition = await AssetLottie(_splashRevealAsset).load();
  } catch (e, st) {
    debugPrint('Failed to preload splash Lottie: $e\n$st');
  }

  // Build the auth state machine and the router before wiring deep links, so
  // out-of-tree navigation (deep links / push) always has a router to target.
  final authController = AuthFlowController()..start();
  appRouter = createAppRouter(
    authController,
    splashComposition: splashComposition,
  );

  locator<PushNotificationManager>().attachForegroundListener();
  locator<PushNotificationManager>().attachOpenedAppListener();
  await locator<DeepLinkService>().initialize();

  return authController;
}

const Color darkGreen = Color(0xFF3D4A3D);
const Color limeGreen = Color(0xFFB8E994);
const Color lightGreen = Color(0xFFE8F5E8);

class MyApp extends StatefulWidget {
  const MyApp({required this.authController, super.key});

  final AuthFlowController authController;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_onAuthStageChanged);
    _onAuthStageChanged();
  }

  /// Marks deep-link navigation ready when auth reaches userReady.
  /// Pending destinations are consumed by GoRouter redirect (auth is the
  /// router refreshListenable). Native splash removal is owned by
  /// [AuthLoadingScreen] once the logo-reveal is ready to paint.
  void _onAuthStageChanged() {
    final stage = widget.authController.stage;
    locator<DeepLinkService>().setNavigationReady(stage == AuthStage.userReady);
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthStageChanged);
    widget.authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MyAppState()),
        ChangeNotifierProvider.value(value: locator<AuthStateManager>()),
        ChangeNotifierProvider.value(value: locator<SubscriptionManager>()),
        ChangeNotifierProvider.value(
          value: locator<StyleAnalysisSessionManager>(),
        ),
        ChangeNotifierProvider.value(value: locator<UserStateManager>()),
        ChangeNotifierProvider.value(value: locator<AssetUploadManager>()),
      ],
      child: _wrapWithPostHog(
        MaterialApp.router(
          routerConfig: appRouter,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: 'Stylens',
          builder: (context, child) => GlobalLoaderScope(child: child!),
          theme: ThemeData(
            fontFamily: 'Metropolis',
            colorScheme:
                ColorScheme.fromSeed(
                  seedColor: darkGreen,
                  primary: darkGreen,
                  secondary: limeGreen,
                  tertiary: lightGreen,
                  contrastLevel: 0.5,
                ).copyWith(
                  surfaceDim: lightGreen,
                  outline: darkGreen.withValues(alpha: 0.3),
                ),
            appBarTheme: AppBarTheme(
              backgroundColor: darkGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
            ),
            navigationBarTheme: NavigationBarThemeData(
              height: 56,
              backgroundColor: darkGreen.withValues(alpha: 0.9),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              indicatorColor: limeGreen.withValues(alpha: 0.2),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: limeGreen, size: 24);
                }
                return IconThemeData(
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 24,
                );
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    color: limeGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    height: 1.0,
                  );
                }
                return TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  height: 1.0,
                );
              }),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: limeGreen,
                foregroundColor: darkGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: darkGreen,
                side: BorderSide(color: darkGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _wrapWithPostHog(Widget child) {
  if (!AnalyticsService.isEnabled) return child;
  return PostHogWidget(child: child);
}

class MyAppState extends ChangeNotifier {}

class ErrorApp extends StatelessWidget {
  const ErrorApp({required this.errorMessage, super.key});

  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: darkGreen,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Failed to start:\n\n$errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
