plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Android FCM token registration can use Dart FirebaseOptions in debug builds.
// Apply google-services only when a matching google-services.json is supplied.
if (providers.gradleProperty("hestiaUseGoogleServices").orNull == "true" &&
    file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("androidx.work:work-runtime-ktx:2.9.1")
}
android {
    namespace = "com.example.hestia"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            // PRODUCTION: Replace with your actual keystore
            // Generate: keytool -genkey -v -keystore ~/hestia-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias hestia
            // keyStore = file(System.getenv("HESTIA_KEYSTORE_PATH") ?: "")
            // keyStorePassword = System.getenv("HESTIA_KEYSTORE_PASSWORD")
            // keyAlias = System.getenv("HESTIA_KEY_ALIAS")
            // keyPassword = System.getenv("HESTIA_KEY_PASSWORD")
            // TODO: Uncomment above and configure for production Play Store distribution
        }
    }

    defaultConfig {
        // PRODUCTION: Replace with your actual app package ID (reverse domain)
        // Example: com.yourcompany.hestia
        applicationId = "org.hestiachat.messenger"
        // Android 8.0 / API 26 is the minimum supported Android version.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // PRODUCTION: Replace "debug" with "release" when keystore is configured
            // signingConfig = signingConfigs.getByName("release")
            // Using debug for now to enable flutter run --release
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}


flutter {
    source = "../.."
}
