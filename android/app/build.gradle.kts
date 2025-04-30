import java.io.File
import java.io.FileInputStream
import java.util.*

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties().apply {
    load(FileInputStream(File("keystore.properties")))
}
val detKeyAlias = keyProperties.getProperty("keyAlias")
require(detKeyAlias != null) { "keyAlias not found in key.properties file." }
val detKeyPassword = keyProperties.getProperty("keyPassword")
val detStoreFile = keyProperties.getProperty("storeFile")
val detStorePassword = keyProperties.getProperty("storePassword")

android {
    namespace = "com.moazsalem.image.sorter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.moazsalem.image.sorter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = detKeyAlias
            keyPassword = detKeyPassword
            storeFile = file(detStoreFile)
            storePassword = detStorePassword
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:2.1.20")
    implementation("androidx.exifinterface:exifinterface:1.4.1")
}
