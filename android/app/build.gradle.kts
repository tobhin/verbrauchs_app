import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(localPropertiesFile.inputStream())
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toInt() ?: 1
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.example.verbrauchs_app"
    compileSdk = 35

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        // Wir erzwingen Java 8, um maximale Kompatibilität mit allen Plugins zu gewährleisten.
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.verbrauchs_app"
        minSdk = 21
        targetSdk = 34
        versionCode = flutterVersionCode
        versionName = flutterVersionName
        multiDexEnabled = true // Wichtig für Apps mit vielen Plugins
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("com.google.mlkit:text-recognition:16.0.0")
}