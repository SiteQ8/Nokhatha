plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.eworldq8.nokhatha"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.eworldq8.nokhatha"
        minSdk = 24
        targetSdk = 36
        // CI numbers every build it sends to Play, because Play refuses a version code it has seen
        versionCode = (System.getenv("NOKHATHA_VERSION_CODE") ?: "1").toInt()
        versionName = System.getenv("NOKHATHA_VERSION_NAME") ?: "1.0.0"
        resourceConfigurations += listOf("ar", "en")
    }

    // The app reads the same seasons, tasks, strings and places files as the web app,
    // straight from docs/data, so the three platforms can never drift apart.
    sourceSets["main"].assets.srcDirs("../../docs/data")

    // The upload key is never stored in the repository: a release build reads it from the environment.
    val keystorePath: String? = System.getenv("NOKHATHA_KEYSTORE")
    signingConfigs {
        create("release") {
            if (keystorePath != null) {
                storeFile = file(keystorePath)
                storePassword = System.getenv("NOKHATHA_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("NOKHATHA_KEY_ALIAS") ?: "nokhatha-upload"
                keyPassword = System.getenv("NOKHATHA_KEY_PASSWORD") ?: System.getenv("NOKHATHA_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            if (keystorePath != null) signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    buildFeatures { compose = true }
    composeOptions { kotlinCompilerExtensionVersion = "1.5.14" }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.4")
    implementation("androidx.activity:activity-compose:1.9.1")
    implementation(platform("androidx.compose:compose-bom:2024.08.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
