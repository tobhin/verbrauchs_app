import java.util.Properties
import java.io.FileInputStream

// Hilfsfunktion, um die Version aus der pubspec.yaml zu lesen
fun getPubspecVersion(): Pair<String, String> {
    val pubspecFile = rootProject.file("../pubspec.yaml")
    val pubspecText = pubspecFile.readText()
    val versionLine = pubspecText.lines().first { it.startsWith("version:") }
    val versionParts = versionLine.split(":").last().trim().split("+")
    val versionName = versionParts[0]
    val versionCode = if (versionParts.size > 1) versionParts[1] else "1"
    return Pair(versionName, versionCode)
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val (pubspecVersionName, pubspecVersionCode) = getPubspecVersion()

android {
    namespace = "com.example.verbrauchs_app"
    compileSdk = 35

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
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
        // KORRIGIERT: Liest jetzt direkt aus der pubspec.yaml
        versionCode = pubspecVersionCode.toInt()
        versionName = pubspecVersionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}