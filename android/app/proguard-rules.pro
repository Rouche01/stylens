# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# shared_preferences — uses Pigeon; must not be obfuscated
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Supabase / Postgrest / Realtime
-keep class io.supabase.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Google Sign-In
-keep class com.google.android.gms.** { *; }

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
