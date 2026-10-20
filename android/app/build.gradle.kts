import java.util.Properties
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
val signingFile = rootProject.file("key.properties")
val signing = Properties().apply { if(signingFile.exists()) signingFile.inputStream().use { load(it) } }
android {
    namespace = "org.appbreak.companion"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
    defaultConfig { applicationId = "org.appbreak.companion"; testInstrumentationRunner = "android.test.InstrumentationTestRunner"; minSdk = 26; targetSdk = 36; versionCode = flutter.versionCode; versionName = flutter.versionName }
    flavorDimensions += "edition"
    productFlavors {
        create("foss") { dimension = "edition" }
        create("play") { dimension = "edition"; applicationIdSuffix = ".play" }
    }
    signingConfigs {
        if(signingFile.exists()) create("owner") {
            storeFile = file(signing.getProperty("storeFile")); storePassword = signing.getProperty("storePassword")
            keyAlias = signing.getProperty("keyAlias"); keyPassword = signing.getProperty("keyPassword")
        }
    }
    buildTypes { release { if(signingFile.exists()) signingConfig = signingConfigs.getByName("owner") } }
}
flutter { source = "../.." }
// Keep any future billing SDK exclusively in playImplementation / src/play.
// No billing, Google Play Services, analytics or third-party plugins in either graph.

// Android's legacy test APIs are optional SDK libraries, compile-only for tests.
dependencies {
    testImplementation("junit:junit:4.13.2")
    androidTestCompileOnly(files("${android.sdkDirectory}/platforms/android-36/optional/android.test.base.jar"))
    androidTestCompileOnly(files("${android.sdkDirectory}/platforms/android-36/optional/android.test.runner.jar"))
}
