import java.util.Properties
import java.util.Base64

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.reader().use { reader ->
        localProperties.load(reader)
    }
}

// Keystore credentials — populated by CI via local.properties or env vars
val ksFile     = localProperties.getProperty("storeFile")
val ksPassword = localProperties.getProperty("storePassword") ?: System.getenv("ANDROID_STORE_PASSWORD") ?: ""
val ksAlias    = localProperties.getProperty("keyAlias")      ?: System.getenv("ANDROID_KEY_ALIAS")       ?: ""
val ksKeyPass  = localProperties.getProperty("keyPassword")   ?: System.getenv("ANDROID_KEY_PASSWORD")    ?: ""

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
        versionCode = if (project.hasProperty("versionCode")) {
            (project.property("versionCode") as String).toInt()
        } else {
            flutter.versionCode
        }
        versionName = if (project.hasProperty("versionName")) {
            project.property("versionName") as String
        } else {
            flutter.versionName
        }

        manifestPlaceholders["posthogApiKey"] = posthogApiKey
        manifestPlaceholders["posthogHost"] = posthogHost
    }

    signingConfigs {
        if (!ksFile.isNullOrEmpty()) {
            create("release") {
                storeFile     = file(ksFile)
                storePassword = ksPassword
                keyAlias      = ksAlias
                keyPassword   = ksKeyPass
            }
        }
    }

    buildTypes {
        release {
            val releaseConfig = signingConfigs.findByName("release")
            signingConfig = releaseConfig ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
