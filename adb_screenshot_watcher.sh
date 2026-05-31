#!/bin/bash
ADB=/Users/richardemate/Library/Android/sdk/platform-tools/adb
$ADB logcat -c
echo "Watching logcat for STYLENS_TEST..."
$ADB logcat -v raw -s flutter | while read line; do
  if [[ "$line" == *"STYLENS_TEST: CAPTURE_"* ]]; then
    name=$(echo "$line" | sed -n 's/.*STYLENS_TEST: CAPTURE_\([a-zA-Z0-9_]*\).*/\1/p' | tr -d '\r')
    if [ ! -z "$name" ]; then
      echo "Intercepted logcat trigger for $name. Waiting 1.5s for animations..."
      sleep 1.5
      echo "Capturing via ADB..."
      $ADB exec-out screencap -p > "android/fastlane/screenshots/en-US/$name.png"
      if [[ "$name" == "screenshot_choose_gallery" ]]; then
        echo "Closing native gallery picker..."
        $ADB shell input keyevent 4
      fi
    fi
  fi
done
