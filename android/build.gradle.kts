// Top-level build file where you can add configuration options common to all sub-projects/modules.

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Ini adalah plugin Android Gradle dan Kotlin Gradle yang sudah ada
        // Anda mungkin memiliki versi yang berbeda di sini, biarkan saja
        classpath("com.android.tools.build:gradle:8.2.0") // Contoh versi, biarkan versi Anda
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0") // Contoh versi, biarkan versi Anda

        // --- TAMBAHKAN BARIS INI UNTUK GOOGLE SERVICES ---
        classpath("com.google.gms:google-services:4.4.1") // Pastikan Anda menggunakan versi terbaru
        // --- AKHIR PENAMBAHAN ---
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}