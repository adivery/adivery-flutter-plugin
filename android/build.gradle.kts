plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

group = "com.adivery.plugin"
version = "1.0"

repositories {
    google()
    mavenCentral()
    maven(url = "https://dl.bintray.com/adivery/maven")
}

android {
    namespace = "com.adivery.plugin"
    compileSdk = 36

    defaultConfig {
        minSdk = 16
    }

    lint {
        disable.add("InvalidPackage")
    }
}

dependencies {
    implementation("com.adivery:sdk:4.9.0")
}
