plugins {
    id("com.android.application")
    id("kotlin-android")
<<<<<<< HEAD
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") 
}

android {
    namespace = "com.example.g11chat_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

=======
    id("dev.flutter.flutter-gradle-plugin")
    classpath 'com.google.gms.google-services:4.4.1'

}
dependencies {
implementation(platform("com.google.firebase:firebase-bom:34.9.0"))

implementation("com.google.firebase:firebase-analytics")

  // Add the dependencies for any other desired Firebase products
  // https://firebase.google.com/docs/android/setup#available-libraries
}

android {
    namespace = "com.example.chartapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.chartapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

>>>>>>> 27551880ef1e78ecbb749df6558c3623fc9ec7d8
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
<<<<<<< HEAD

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.g11chat_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
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
=======
>>>>>>> 27551880ef1e78ecbb749df6558c3623fc9ec7d8
}

flutter {
    source = "../.."
}
<<<<<<< HEAD
dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.9.0"))
}
=======
>>>>>>> 27551880ef1e78ecbb749df6558c3623fc9ec7d8
