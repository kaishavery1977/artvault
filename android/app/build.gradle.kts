import java.io.FileInputStream
import java.util.Properties

// Release signing. Credentials live in android/key.properties (git-ignored,
// not committed); when the file is absent — e.g. a fresh clone without the
// keystore — release builds fall back to the debug key so the project still
// builds, matching the pre-existing TODO behaviour.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { input ->
        keystoreProperties.load(input)
    }
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.artvault.artvault"
    // flutter_secure_storage & permission_handler_android require compileSdk 37.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications requires core library desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.artvault.artvault"
        // ArtVault: Firebase, ML Kit, local_auth and mobile_scanner all require minSdk 23+.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // No key.properties (keystore not present): fall back to the
                // debug key so `flutter run --release` still works.
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.biometric:biometric:1.1.0")
    // Required by the camera plugin (androidx.camera 1.6+) to resolve
    // androidx.concurrent.futures.CallbackToFutureAdapter at compile time.
    implementation("androidx.concurrent:concurrent-futures:1.2.0")
    // TensorFlow Lite runtime for the on-device face-embedding model.
    // Used directly from MainActivity via a MethodChannel (tflite_flutter's
    // plugin module is incompatible with the current AGP 9 toolchain).
    // 2.16.x is required: 2.11's -lite/-api/-gpu artifacts all declared the
    // same org.tensorflow.lite namespace, which AGP 9's manifest merger
    // rejects.
    implementation("org.tensorflow:tensorflow-lite:2.16.1")
}

flutter {
    source = "../.."
}
