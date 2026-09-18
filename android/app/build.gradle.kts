plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.jadwalpintar"
    // compileSdk 36 = syarat plugin terbaru (file_picker); perilaku runtime
    // tetap dikunci targetSdk 26.
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Wajib: flutter_local_notifications memakai API Java 8+ (java.time)
        // yang tidak ada di API 24-25.
        isCoreLibraryDesugaringEnabled = true
    }

    lint {
        // Sideload (bukan Play Store): matikan lint vital release agar
        // targetSdk 26 (paritas perilaku) tidak menggagalkan build.
        abortOnError = false
        checkReleaseBuilds = false
        disable += "ExpiredTargetSdkVersion"
    }

    defaultConfig {
        minSdk = 24
        // targetSdk dipertahankan 26 (paritas perilaku alarm/notifikasi/storage
        // dengan aplikasi native; bukan rilis Play Store).
        targetSdk = 26
        versionCode = 4
        versionName = "4.0.0"
        // Hanya arm64: semua HP target 64-bit; APK lebih kecil
        // (tanpa armeabi-v7a & x86_64).
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    signingConfigs {
        create("ci") {
            val ksFile = System.getenv("KEYSTORE_FILE")
            if (!ksFile.isNullOrEmpty()) {
                storeFile = file(ksFile)
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            val ksFile = System.getenv("KEYSTORE_FILE")
            signingConfig = if (!ksFile.isNullOrEmpty()) {
                signingConfigs.getByName("ci")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    flavorDimensions += "app"
    productFlavors {
        create("user") {
            dimension = "app"
            applicationId = "com.jadwalpintar.app"
            manifestPlaceholders["applicationLabel"] = "Jadwal Pintar"
        }
        create("admin") {
            dimension = "app"
            applicationId = "com.jadwalpintar.admin"
            manifestPlaceholders["applicationLabel"] = "Admin Jadwal Pintar"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
