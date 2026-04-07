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

android {
    val signingProperties = Properties()
    val signingPropertiesFile = rootProject.file("key.properties")
    if (signingPropertiesFile.exists()) {
        signingPropertiesFile.inputStream().use(signingProperties::load)
    }

    val releaseStoreFile =
        signingProperties.getProperty("storeFile")
            ?: System.getenv("BILLRAJA_UPLOAD_STORE_FILE")
    val releaseStorePassword =
        signingProperties.getProperty("storePassword")
            ?: System.getenv("BILLRAJA_UPLOAD_STORE_PASSWORD")
    val releaseKeyAlias =
        signingProperties.getProperty("keyAlias")
            ?: System.getenv("BILLRAJA_UPLOAD_KEY_ALIAS")
    val releaseKeyPassword =
        signingProperties.getProperty("keyPassword")
            ?: System.getenv("BILLRAJA_UPLOAD_KEY_PASSWORD")

    val hasReleaseSigning =
        !releaseStoreFile.isNullOrBlank() &&
        !releaseStorePassword.isNullOrBlank() &&
        !releaseKeyAlias.isNullOrBlank() &&
        !releaseKeyPassword.isNullOrBlank()

    namespace = "com.luhit.billeasy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.luhit.billeasy"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "Release signing credentials not found. " +
                        "Using debug signing for local release builds only. " +
                        "Add android/key.properties or BILLRAJA_UPLOAD_* env vars before publishing."
                )
                signingConfigs.getByName("debug")
            }
        }
        debug {
            isDebuggable = true
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
