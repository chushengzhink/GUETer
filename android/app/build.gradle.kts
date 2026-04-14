import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystoreProperties = keystorePropertiesFile.exists()
if (hasKeystoreProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else {
    println("key.properties not found. Release signing will be disabled.")
}

android {
    namespace = "com.anerycoft.coursehelperplus"
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
        applicationId = "com.anerycoft.coursehelperplus"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Keep default ABI config. Use `flutter build apk --split-per-abi`
        // to generate dedicated arm64 package when needed.
    }

    signingConfigs {
        if (hasKeystoreProperties) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"])
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }


    buildTypes {
        release {
            if (hasKeystoreProperties) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
            // signingConfig = signingConfigs.getByName("debug")
            
            // 启用代码混淆
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // 禁用 lint 检查以加快构建速度并避免文件锁定问题
            lint {
                checkDependencies = false
                abortOnError = false
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.baidu.lbsyun:BaiduMapSDK_Map:7.6.7")
    // flutter_bmflocation 插件已包含 BaiduMapSDK_Location_All
    implementation("com.baidu.lbsyun:BaiduMapSDK_Util:7.6.7")
}
