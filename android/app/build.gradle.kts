plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Dies ist die Kotlin-Version, um die Properties zu lesen
val localProperties = java.util.Properties()
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
        // HINZUGEFÜGT: Für flutter_local_notifications benötigt
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.verbrauchs_app"
        minSdk = 21
        targetSdk = 34 // targetSdk wird oft noch auf 34 belassen, compileSdk ist wichtiger
        versionCode = flutterVersionCode
        versionName = flutterVersionName
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
    // HINZUGEFÜGT: Für flutter_local_notifications benötigt
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // HINZUGEFÜGT: Für die Texterkennung benötigt
    implementation("com.google.mlkit:text-recognition:16.0.0")
}