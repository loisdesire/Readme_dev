pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.3.15") apply false
    // END: FlutterFire Configuration
    // Bumped from 2.1.0: the Firebase Auth Android AAR now ships Kotlin
    // metadata that 2.1.0 can't read ("Module was compiled with an
    // incompatible version of Kotlin... expected 2.1.0"), which broke
    // `assembleRelease` outright — a pre-existing Gradle config issue,
    // unrelated to any Dart/Flutter package version. See SECURITY.md.
    id("org.jetbrains.kotlin.android") version "2.4.20" apply false
}

include(":app")
