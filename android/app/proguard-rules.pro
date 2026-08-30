# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Keep every Flutter plugin implementation. R8 can otherwise drop plugins that
# are only referenced from GeneratedPluginRegistrant / onAttachedToEngine, which
# surfaces as PlatformException(channel-error) on Pigeon channels in release.
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keepclassmembers class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }

# shared_preferences — SharedPreferences.getInstance() uses the legacy Pigeon
# API (SharedPreferencesApi.getAll). LegacySharedPreferencesPlugin is constructed
# inside SharedPreferencesPlugin and is easy for R8 to treat as unreachable.
# See https://github.com/flutter/flutter/issues/153075
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keepclassmembers class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.sharedpreferences.LegacySharedPreferencesPlugin { *; }
-keep class io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin { *; }
-keep class io.flutter.plugins.sharedpreferences.SharedPreferencesApi { *; }
-keep class io.flutter.plugins.sharedpreferences.SharedPreferencesAsyncApi { *; }

# path_provider (often hits the same channel-error class of failure)
-keep class io.flutter.plugins.pathprovider.** { *; }

# Supabase / Postgrest / Realtime
-keep class io.supabase.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Google Sign-In
-keep class com.google.android.gms.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }

# RevenueCat (purchases_flutter)
-keep class com.revenuecat.** { *; }

# PostHog analytics
-keep class com.posthog.** { *; }

# OkHttp / Retrofit (used by many networking libs)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Prevent stripping of classes used via reflection
-keepattributes EnclosingMethod
-keepattributes InnerClasses
