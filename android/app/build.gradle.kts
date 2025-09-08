// Path: C:\vscode_projek\projek\project_strata_lite\android\app\build.gradle.kts

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.strata_lite"
    compileSdk = flutter.compileSdkVersion
    
    // UBAH BARIS INI:
    ndkVersion = "27.0.12077973" // Paksa menggunakan versi NDK yang lebih tinggi

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17 // Diperbarui ke Java 17
        targetCompatibility = JavaVersion.VERSION_17 // Diperbarui ke Java 17
    }

    kotlinOptions {
        jvmTarget = "1.8" // Diperbarui ke 1.8 agar kompatibel dengan plugin pihak ketiga
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.strata_lite"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.compileSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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