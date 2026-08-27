plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Navigation runs on MapLibre against the self-hosted road graph, so the app no
// longer carries a Google Maps API key or the Navigation SDK.

dependencies {
    // Native foreground camera detector uses the same ML Kit runtime as the
    // Flutter face-detection plugin, but app code needs direct compile access.
    implementation("com.google.mlkit:vision-common:17.3.0")
    implementation("com.google.mlkit:face-detection:16.1.7")
    implementation("com.google.mlkit:face-mesh-detection:16.0.0-beta1")
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.28.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.5")
}

configurations.configureEach {
    // google_mlkit_image_labeling 0.15.0 pulls linkfirebase:17.0.0, whose
    // retired firebase-iid:20.1.5 packages the same receiver as current FCM.
    // SafeFleet uses the bundled/default image labeler, not Firebase-hosted
    // custom models, so the obsolete IID runtime must not enter the APK.
    exclude(group = "com.google.firebase", module = "firebase-iid")
}

val releaseStoreFile = System.getenv("SAFEEFLEET_ANDROID_STORE_FILE")
val releaseStorePassword = System.getenv("SAFEEFLEET_ANDROID_STORE_PASSWORD")
val releaseKeyAlias = System.getenv("SAFEEFLEET_ANDROID_KEY_ALIAS")
val releaseKeyPassword = System.getenv("SAFEEFLEET_ANDROID_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

if (
    gradle.startParameter.taskNames.any {
        it.contains("release", ignoreCase = true)
    } && !hasReleaseSigning
) {
    throw GradleException(
        "Release signing is required. Set SAFEFLEET_ANDROID_STORE_FILE, " +
            "SAFEEFLEET_ANDROID_STORE_PASSWORD, SAFEFLEET_ANDROID_KEY_ALIAS " +
            "and SAFEFLEET_ANDROID_KEY_PASSWORD.",
    )
}

android {
    namespace = "vn.safefleet.safe_fleet_driver_ui"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    androidResources {
        noCompress += "onnx"
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "vn.safefleet.safe_fleet_driver_ui"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
