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
        // CORREÇÃO: No Kotlin DSL usamos 'isCoreLibraryDesugaringEnabled'
        isCoreLibraryDesugaringEnabled = true
        
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // CORREÇÃO: Ajustado para evitar o aviso de 'deprecated'
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.geoponto"
        
        // Mínimo necessário para as bibliotecas de Ponto e Firebase
        minSdk = flutter.minSdkVersion 

        // Necessário para o Firebase não travar na compilação
        multiDexEnabled = true

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Biblioteca de tradução de recursos Java 8+
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
