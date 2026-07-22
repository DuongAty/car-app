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

// Some plugins (e.g. flutter_volume_controller 2.0.1) still declare an old
// compileSdk that is too low for the lifecycle package Flutter now injects
// into every plugin module. Raising it here avoids depending on a pub-cache
// patch that would not survive a fresh `flutter pub get` elsewhere.
//
// Must be registered before `evaluationDependsOn` below, which otherwise
// forces some subprojects to evaluate eagerly and makes this afterEvaluate
// call fail with "project is already evaluated".
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { androidExtension ->
            if (androidExtension is com.android.build.gradle.BaseExtension) {
                androidExtension.compileSdkVersion(36)
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
