plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.geoponto"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Habilita suporte a Java 8+ em Androids antigos
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // Forma correta de definir o target no Kotlin DSL
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.geoponto"
        
        // Mínimo para Firebase e GPS
        minSdk = flutter.minSdkVersion 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true
    }

    buildTypes {
        getByName("release") {
            // Usamos a chave de debug para o APK funcionar sem precisar criar uma JKS agora
            signingConfig = signingConfigs.getByName("debug")

            // CORREÇÃO AQUI: No .kts o nome correto tem o prefixo 'is'
            isMinifyEnabled = false
            isShrinkResources = false
            
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Biblioteca de "tradução" para recursos Java 8+
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
