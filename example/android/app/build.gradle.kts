import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.reader().use { load(it) }
    }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toInt() ?: 1
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"
val flutterMinSdkVersion = localProperties.getProperty("flutter.minSdkVersion")?.toIntOrNull() ?: 23

android {
    namespace = "com.adivery.plugin_example"
    compileSdk = 36
    lint {
        disable.add("InvalidPackage")
    }

    defaultConfig {
        applicationId = "com.adivery.plugin_example"
        minSdk = flutterMinSdkVersion
        targetSdk = 36
        versionCode = flutterVersionCode
        versionName = flutterVersionName
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.mbridge.msdk.oversea:mbridge_android_sdk:16.9.71")
}
