import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

repositories {
    google()
    mavenCentral()
}

android {
    namespace = "com.cityuniversity.uniqueue"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }


    defaultConfig {
        applicationId = "com.cityuniversity.uniqueue"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        multiDexEnabled = true
        targetSdk = flutter.targetSdkVersion
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
kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    val localProperties = Properties()
    rootProject.file("local.properties").inputStream().use { localProperties.load(it) }
    val flutterSdkPath = requireNotNull(localProperties.getProperty("flutter.sdk"))
    val engineVersion = file("$flutterSdkPath\\bin\\cache\\engine.stamp").readText().trim()
    add("debugApi", "io.flutter:flutter_embedding_debug:1.0.0-$engineVersion")
    add("profileApi", "io.flutter:flutter_embedding_profile:1.0.0-$engineVersion")
    add("releaseApi", "io.flutter:flutter_embedding_release:1.0.0-$engineVersion")
}

flutter {
    source = "../.."
}
