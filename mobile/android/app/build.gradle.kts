import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        // Replace with your real application id before release (e.g. cl.tuorg.nearpharma)
        applicationId = System.getenv("APPLICATION_ID") ?: "cl.nearpharma.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Use release signing config if available. Keep debug signing only for local testing.
                // Read signing properties from key.properties (not checked into repo)
                val keyPropsFile = rootProject.file("../key.properties")
                if (keyPropsFile.exists()) {
                    // Read key.properties using Kotlin file APIs (avoid java.util/java.io references in the script)
                    val lines = keyPropsFile.readLines().map { it.trim() }.filter { it.isNotEmpty() && !it.startsWith("#") }
                    val map = lines.mapNotNull {
                        val parts = it.split("=", limit = 2)
                        if (parts.size == 2) parts[0].trim() to parts[1].trim() else null
                    }.toMap()
                    val storeFilePath = map["storeFile"]
                    if (!storeFilePath.isNullOrEmpty()) {
                        signingConfigs {
                            create("release") {
                                storeFile = file(storeFilePath)
                                storePassword = map["storePassword"]
                                keyAlias = map["keyAlias"]
                                keyPassword = map["keyPassword"]
                            }
                        }
                        signingConfig = signingConfigs.getByName("release")
                    } else {
                        // fallback to debug signing when no key properties found (local dev)
                        signingConfig = signingConfigs.getByName("debug")
                    }
                } else {
                    signingConfig = signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}
