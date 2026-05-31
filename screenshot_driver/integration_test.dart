import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot:
        (
          String name,
          List<int> imageBytes, [
          Map<String, dynamic>? args,
        ]) async {
          final String path = 'android/fastlane/screenshots/en-US/$name.png';

          if (name == 'screenshot_choose_gallery') {
            print('Intercepted $name - Capturing via ADB to ensure perfect physical rendering...');
            final result = await Process.run('sh', [
              '-c',
              '/Users/richardemate/Library/Android/sdk/platform-tools/adb exec-out screencap -p > $path',
            ]);
            if (result.exitCode != 0) {
              print('ADB capture failed: ${result.stderr}');
            }

            print('Closing native gallery picker...');
            await Process.run('/Users/richardemate/Library/Android/sdk/platform-tools/adb', ['shell', 'input', 'keyevent', '4']);
            return true;
          }

          // Normal Flutter surface capture for all other screens
          final File image = await File(path).create(recursive: true);
          await image.writeAsBytes(imageBytes);
          return true;
        },
  );
}
