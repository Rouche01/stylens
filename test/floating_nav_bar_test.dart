import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/widgets/floating_nav_bar.dart';

const _primary = Color(0xFF3D4A3D);
const _lime = Color(0xFFB8E994);

Widget _app({
  required int selectedIndex,
  bool closetProcessing = false,
  bool reduceMotion = false,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primary,
        primary: _primary,
        secondary: _lime,
      ),
    ),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Center(
          child: FloatingNavBar(
            selectedIndex: selectedIndex,
            closetProcessing: closetProcessing,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows a pulse dot on Closet when processing off that tab', (
    tester,
  ) async {
    await tester.pumpWidget(_app(selectedIndex: 1, closetProcessing: true));
    await tester.pump();

    expect(find.byKey(const ValueKey('closet-hanger-pulse')), findsOneWidget);
    expect(find.bySemanticsLabel('Closet, hanging pieces'), findsOneWidget);
  });

  testWidgets('hides the pulse when Closet is selected', (tester) async {
    await tester.pumpWidget(_app(selectedIndex: 0, closetProcessing: true));
    await tester.pump();

    expect(find.byKey(const ValueKey('closet-hanger-pulse')), findsNothing);
    expect(find.bySemanticsLabel('Closet'), findsOneWidget);
  });

  testWidgets('hides the pulse when idle', (tester) async {
    await tester.pumpWidget(_app(selectedIndex: 1));
    await tester.pump();

    expect(find.byKey(const ValueKey('closet-hanger-pulse')), findsNothing);
    expect(find.bySemanticsLabel('Closet'), findsOneWidget);
  });

  testWidgets('keeps a static dot when motion is reduced', (tester) async {
    await tester.pumpWidget(
      _app(selectedIndex: 2, closetProcessing: true, reduceMotion: true),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('closet-hanger-pulse')), findsOneWidget);
    expect(find.bySemanticsLabel('Closet, hanging pieces'), findsOneWidget);
  });
}
