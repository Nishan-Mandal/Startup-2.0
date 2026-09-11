import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

dependencies {
  // Import the Firebase BoM
  implementation(platform("com.google.firebase:firebase-bom:34.2.0"))


  // TODO: Add the dependencies for Firebase products you want to use
  // When using the BoM, don't specify versions in Firebase dependencies
  implementation("com.google.firebase:firebase-analytics")

  //Local Notification
  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
  implementation("androidx.window:window:1.0.0")
  implementation("androidx.window:window-java:1.0.0")


  // Add the dependencies for any other desired Firebase products
  // https://firebase.google.com/docs/android/setup#available-libraries
}


val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {


    namespace = "com.example.startup2"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        //Local Notification
        // Flag to enable support for the new language APIs
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.findon.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val hasReleaseSigning = keystorePropertiesFile.exists() &&
    keystoreProperties["keyAlias"]?.toString()?.isNotBlank() == true &&
    keystoreProperties["keyPassword"]?.toString()?.isNotBlank() == true &&
    keystoreProperties["storePassword"]?.toString()?.isNotBlank() == true &&
    keystoreProperties["storeFile"]?.toString()?.isNotBlank() == true &&
    rootProject.file(keystoreProperties["storeFile"].toString()).exists()

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
               keyAlias = keystoreProperties["keyAlias"].toString()
               keyPassword = keystoreProperties["keyPassword"].toString()
               storeFile = rootProject.file(keystoreProperties["storeFile"].toString())
               storePassword = keystoreProperties["storePassword"].toString()
           }
       }
   }

   buildTypes {
       release {
           signingConfig = if (hasReleaseSigning) {
               signingConfigs.getByName("release")
          } else {
              signingConfigs.getByName("debug")
          }
       }
    }
}



flutter {
    source = "../.."
}
