plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.verbrauchs_app"
    compileSdk = 34 // Aktualisiert auf 34

    // Passend zu deiner aktuellen Umgebung
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Wichtig für flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.verbrauchs_app"
        minSdk = 21 // ERHÖHT auf 21 für ML Kit
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
        }
        getByName("profile") {
            isMinifyEnabled = false
        }
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Debug-Key für Testbuilds – später für PlayStore ersetzen
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // schon vorhanden:
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // ML Kit Text Recognition Artefakte (alle Skripte)
    implementation("com.google.mlkit:text-recognition:16.0.0")
}