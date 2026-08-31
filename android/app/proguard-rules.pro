# App-specific R8 rules. Flutter's Gradle plugin also applies
# packages/flutter_tools/gradle/flutter_proguard_rules.pro automatically.

# shared_preferences: legacy Pigeon API (SharedPreferencesApi.getAll) is wired up
# from LegacySharedPreferencesPlugin, which is constructed inside
# SharedPreferencesPlugin — R8 can strip it in release without an explicit keep.
# https://github.com/flutter/flutter/issues/153075
-keep class io.flutter.plugins.sharedpreferences.LegacySharedPreferencesPlugin { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# path_provider — same class of channel-error failures under R8
-keep class io.flutter.plugins.pathprovider.** { *; }
