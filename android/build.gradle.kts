<<<<<<< HEAD
// Agora RTC đọc rootProject.ext.compileSdkVersion. Nếu không khai báo,
// plugin tự biên dịch với Android SDK 31 và lỗi checkDebugAarMetadata.
extra["compileSdkVersion"] = 36

=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

<<<<<<< HEAD
// Plugin Agora tự fallback compileSdk 31 nếu không đọc được ext.
// Ép SDK 36 khi module còn đang cấu hình, hoặc ngay nếu Gradle đã đánh giá xong.
subprojects {
    fun Project.forceLibraryCompileSdk() {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.compileSdkVersion(36)
    }
    if (state.executed) {
        forceLibraryCompileSdk()
    } else {
        afterEvaluate { forceLibraryCompileSdk() }
    }
}

=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
