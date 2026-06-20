import 'package:flutter/material.dart';
import 'package:gostylens/core/services/analytics_service.dart';
import 'package:gostylens/core/managers/auth_state_manager.dart';
import 'package:provider/provider.dart';
import 'package:gostylens/navigation/auth_gate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'core/managers/style_analysis_session/index.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:gostylens/core/managers/global_loader/global_loader_scope.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:gostylens/core/managers/asset_upload_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:gostylens/core/managers/push_notification_manager.dart';
import 'package:gostylens/core/navigation/app_navigation_keys.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_service.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Warm up the SharedPreferences Pigeon channel before any plugin uses it.
  // On release builds, PostHog/Supabase call shared_preferences internally
  // during init — if the channel isn't established first, it throws a
  // PlatformException(channel-error) and crashes the app.
  await SharedPreferences.getInstance();

  try {
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
    locator<PushNotificationManager>().attachForegroundListener();
    locator<PushNotificationManager>().attachOpenedAppListener();
    await locator<DeepLinkService>().initialize();

    runApp(const MyApp());
  } catch (e) {
    FlutterNativeSplash.remove();
    runApp(ErrorApp(errorMessage: e.toString()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color darkGreen = Color(0xFF3D4A3D);
  static const Color limeGreen = Color(0xFFB8E994);
  static const Color lightGreen = Color(0xFFE8F5E8);

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
        MaterialApp(
          navigatorKey: rootNavigatorKey,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: 'Stylens',
          navigatorObservers: AnalyticsService.isEnabled
              ? [PosthogObserver()]
              : const [],
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
          home: const AuthGate(),
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
        body: Center(child: Text('Failed to load environment: $errorMessage')),
      ),
    );
  }
}
