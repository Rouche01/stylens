import 'package:flutter/material.dart';
import 'package:flutter_env_config/flutter_env_config.dart';
import 'package:flutter_env_config/enums/env_enum.dart';
import 'package:provider/provider.dart';
import 'package:stylens_app/core/managers/global_loader/index.dart';
import 'core/managers/style_analysis_session/index.dart';
import 'pages/closet.dart';
import 'pages/capture.dart';
import 'pages/history.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await FlutterEnvConfig.init(
      configFile: 'assets/config.json',
      targetEnvironment: Environment.dev,
    );
    runApp(MyApp());
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
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    Widget page;

    switch (selectedIndex) {
      case 0:
        page = ClosetPage();
      case 1:
        page = CapturePage();
      case 2:
        page = HistoryPage();
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return GlobalLoaderScope(
      child: Scaffold(
        body: page,
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.checkroom),
              label: 'Closet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: 'Capture',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
          ],
          currentIndex: selectedIndex,
          onTap: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
        ),
      ),
    );
  }
}

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
