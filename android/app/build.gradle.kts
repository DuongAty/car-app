import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Khoá ký release. File này nằm ngoài git (android/.gitignore) và trỏ tới một
// keystore nằm ngoài repo, vì DuongAty/car-app là repo công khai: ai cầm được
// khoá ký là ký được bản cập nhật giả mạo mà mọi máy khách sẽ cài không hỏi.
//
// Máy nào không có file này (máy khác, CI) vẫn build debug được; chỉ build
// release là hỏng, và hỏng ồn ào thay vì âm thầm ký bằng khoá debug — ký nhầm
// khoá thì bản đó không bao giờ cài đè lên máy khách được.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.example.viet_ktv"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.viet_ktv"
        // Android 8.0. Hạ từ 28 xuống khi chưa có máy khách nào cài, để nhận
        // được các box và đầu xe đời cũ. Lưu ý đánh đổi: xoay khoá ký (APK
        // Signature Scheme v3) cần API 28, nên máy Android 8 sẽ không bao giờ
        // nhận được một lần đổi khoá ký. Đừng NÂNG số này sau khi đã bán hàng:
        // máy dưới mốc mới sẽ tải bản cập nhật rồi bị Android từ chối cài, lặp
        // lại mỗi lần kiểm tra.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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

dependencies {
    implementation("io.github.quanghd96:MusicSDK:1.0.0")
}
