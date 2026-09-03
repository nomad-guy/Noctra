plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nomadguy.noctra"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            storeFile = file("noctra-release.keystore")
            val ksPw = System.getenv("NOCTRA_KEYSTORE_PASSWORD")
            val keyPw = System.getenv("NOCTRA_KEY_PASSWORD")
            val keyAlias = System.getenv("NOCTRA_KEY_ALIAS") ?: "noctra"
            val releaseRequested = gradle.startParameter.taskNames.any { task ->
                task.contains("Release", ignoreCase = true) ||
                    task.contains("Bundle", ignoreCase = true)
            }
            if (ksPw.isNullOrBlank() || keyPw.isNullOrBlank()) {
                if (releaseRequested) {
                    // Fail fast ONLY when a release artifact was actually
                    // requested — never block assembleDebug/assembleProfile
                    // for developers without signing secrets.
                    throw GradleException(
                        "Release signing requires NOCTRA_KEYSTORE_PASSWORD and NOCTRA_KEY_PASSWORD " +
                        "environment variables. Set them in ~/.gradle/gradle.properties or CI secrets."
                    )
                }
                // Debug/profile builds don't use this config; leave the
                // passwords empty so configuration never throws.
                storePassword = ""
                this.keyAlias = keyAlias
                keyPassword = ""
            } else {
                storePassword = ksPw
                this.keyAlias = keyAlias
                keyPassword = keyPw
            }
        }
    }

    defaultConfig {
        applicationId = "com.nomadguy.noctra"
        // just_audio 0.10 (Media3 ExoPlayer) requires API 21 minimum
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Media3 can push method count over 64k — multiDex handles it
        multiDexEnabled = true
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
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
