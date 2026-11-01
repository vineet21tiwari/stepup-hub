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
// Force plugin modules (e.g. :jni) onto the same NDK as :app; the local NDK 28.2.13676358
// install is an empty/corrupt folder. Also lift old plugins (file_picker compiles against 34)
// to compileSdk 36, which flutter_plugin_android_lifecycle requires.
subprojects {
    if (name != "app") {
        afterEvaluate {
            extensions.findByName("android")?.let {
                val android = it as com.android.build.api.dsl.CommonExtension
                android.ndkVersion = "27.0.12077973"
                if ((android.compileSdk ?: 0) < 36) android.compileSdk = 36
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
