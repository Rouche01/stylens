import 'package:flutter/material.dart';
import 'package:gostylens/core/managers/auth_state_manager.dart';
import 'package:provider/provider.dart';
import 'package:gostylens/widgets/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'core/managers/style_analysis_session/index.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    await dotenv.load(fileName: ".env");

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );

    runApp(const MyApp());
  } catch (e) {
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
        ChangeNotifierProvider(create: (_) => StyleAnalysisSessionManager()),
        ChangeNotifierProvider(create: (_) => AuthStateManager()),
        ChangeNotifierProvider(create: (_) => UserStateManager()),
      ],
      child: MaterialApp(
        title: 'Stylens',
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
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: darkGreen,
            selectedItemColor: limeGreen,
            unselectedItemColor: Colors.white70,
            type: BottomNavigationBarType.fixed,
            elevation: 8,
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
    );
  }
}

class MyAppState extends ChangeNotifier {}

class ErrorApp extends StatelessWidget {
  const ErrorApp({required this.errorMessage, super.key});

  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Failed to load environment: $errorMessage')),
      ),
    );
  }
}
