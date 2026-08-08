import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

fun signingValue(propertyName: String, environmentName: String): String? =
    keystoreProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }
        ?: System.getenv(environmentName)?.takeIf { it.isNotBlank() }

val releaseStoreFilePath = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "ANDROID_STORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
val releaseSigningConfigured = listOf(
    releaseStoreFilePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

val validationBuild = providers.gradleProperty("validationBuild").orNull == "true"
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseTaskRequested && !validationBuild && !releaseSigningConfigured) {
    throw GradleException(
        "Production release signing is not configured. Provide ignored android/key.properties " +
            "or the protected ANDROID_KEYSTORE_PATH/ANDROID_STORE_PASSWORD/ANDROID_KEY_ALIAS/" +
            "ANDROID_KEY_PASSWORD environment variables. Use -PvalidationBuild=true only for " +
            "a non-production validation build."
    )
}

android {
    namespace = "com.dukaandhisme.dhisme_pos"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Keep this identifier stable so pilot installs can upgrade in place.
        applicationId = "com.dukaandhisme.dhisme_pos"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = file(releaseStoreFilePath!!)
                storePassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            // Validation builds are explicitly debug-signed. Production release
            // tasks require protected release-signing credentials.
            signingConfig = if (releaseSigningConfigured) {
                signingConfigs.getByName("release")
            } else if (validationBuild) {
                signingConfigs.getByName("debug")
            } else {
                null
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
