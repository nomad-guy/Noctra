plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials: android/key.properties (git-ignored) is the
// primary source; NOCTRA_* environment variables / -P properties override it.
import java.util.Properties
val noctraKeyProps = Properties().apply {
    val f = project.rootProject.file("key.properties")
    if (f.exists()) {
        f.inputStream().use { load(it) }
    }
}

fun noctraSecret(env: String, propsKey: String): String? =
    System.getenv(env)
        ?: (project.findProperty(env) as? String)
        ?: noctraKeyProps.getProperty(propsKey)

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
            val ksPw = noctraSecret("NOCTRA_KEYSTORE_PASSWORD", "storePassword")
            val keyPw = noctraSecret("NOCTRA_KEY_PASSWORD", "keyPassword")
            val keyAlias = noctraSecret("NOCTRA_KEY_ALIAS", "keyAlias")
                ?: "noctra"

            if (!ksPw.isNullOrBlank() && !keyPw.isNullOrBlank() && storeFile?.exists() == true) {
                storePassword = ksPw
                this.keyAlias = keyAlias
                keyPassword = keyPw
            } else {
                storePassword = ""
                this.keyAlias = keyAlias
                keyPassword = ""
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
            val releaseSigning = signingConfigs.getByName("release")
            val hasReleaseKeys = !releaseSigning.storePassword.isNullOrBlank() &&
                !releaseSigning.keyPassword.isNullOrBlank()
            val enforceReleaseSigning = System.getenv("CI") == "true" ||
                (project.findProperty("NOCTRA_ENFORCE_SIGNING") as? String) == "true"

            if (hasReleaseKeys) {
                signingConfig = releaseSigning
            } else if (enforceReleaseSigning) {
                throw GradleException(
                    "Release signing requires NOCTRA_KEYSTORE_PASSWORD and NOCTRA_KEY_PASSWORD " +
                    "environment variables or Gradle properties in CI / production release builds."
                )
            } else {
                logger.warn(
                    "NOCTRA WARNING: Release signing credentials not found. " +
                    "Signing release build with debug keystore for local testing and auditing."
                )
                signingConfig = signingConfigs.getByName("debug")
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
