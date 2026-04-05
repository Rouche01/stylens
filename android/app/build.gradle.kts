import java.util.Properties
import java.util.Base64

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.reader().use { reader ->
        localProperties.load(reader)
    }
}

val dartDefines = if (project.hasProperty("dart-defines")) {
    (project.property("dart-defines") as String).split(",").associate {
        val decoded = String(Base64.getDecoder().decode(it))
        val split = decoded.split("=")
        split[0] to (if (split.size > 1) split[1] else "")
    }
} else {
    emptyMap<String, String>()
}

val environment = dartDefines["ENV"] ?: "development"
val envFile = rootProject.file("../.env.$environment")
val envProperties = Properties()
if (envFile.exists()) {
    envFile.reader().use { reader ->
        envProperties.load(reader)
    }
}

val posthogApiKey = envProperties.getProperty("POSTHOG_API_KEY")?.replace("\"", "") ?: ""
val posthogHost = envProperties.getProperty("POSTHOG_HOST")?.replace("\"", "") ?: ""

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.stylenslab.gostylens"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.stylenslab.gostylens"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["posthogApiKey"] = posthogApiKey
        manifestPlaceholders["posthogHost"] = posthogHost
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
