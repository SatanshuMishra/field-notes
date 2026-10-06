plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.satanshumishra.field_notes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.satanshumishra.field_notes"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
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
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.work:work-runtime:2.11.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20250517")
}

flutter {
    source = "../.."
}

val googleTelemetryGroups = listOf(
    "com.google.mlkit",
    "com.google.android.datatransport",
    "com.google.firebase",
    "com.google.android.gms",
)

val checkNoGoogleTelemetry by tasks.registering {
    val releaseClasspath = configurations.named("releaseRuntimeClasspath")
    doLast {
        val found = releaseClasspath.get().incoming.resolutionResult.allComponents
            .mapNotNull { (it.id as? org.gradle.api.artifacts.component.ModuleComponentIdentifier)?.group }
            .filter { group -> googleTelemetryGroups.any { group.startsWith(it) } }
            .distinct()
            .sorted()
        check(found.isEmpty()) { "The release build would carry Google telemetry libraries: $found" }
    }
}

tasks.named("preBuild") { dependsOn(checkNoGoogleTelemetry) }
