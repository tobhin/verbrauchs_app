plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

def localProperties = new Properties()
def localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader("UTF-8") { reader ->
        localProperties.load(reader)
    }
}

def flutterVersionCode = localProperties.getProperty("flutter.versionCode")
if (flutterVersionCode == null) {
    flutterVersionCode = "1"
}

def flutterVersionName = localProperties.getProperty("flutter.versionName")
if (flutterVersionName == null) {
    flutterVersionName = "1.0"
}

android {
    namespace = "com.example.verbrauchs_app"
    compileSdk = 35 // Wir verwenden die neueste SDK-Version, die wir zuvor ermittelt haben

    compileOptions {
        // HINZUGEFÜGT: Für flutter_local_notifications benötigt
        coreLibraryDesugaringEnabled true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.verbrauchs_app"
        minSdk = 21 // Wir setzen das Minimum auf 21, wie für ML Kit benötigt
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInteger()
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