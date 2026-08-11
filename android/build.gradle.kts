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

// The camera plugin (androidx.camera 1.6.x) references
// androidx.concurrent.futures.CallbackToFutureAdapter in its API jar but does
// not declare the dependency, so the plugin module fails to compile with
// "class file for androidx.concurrent.futures.CallbackToFutureAdapter not
// found". Inject it into the camera plugin modules.
subprojects {
    if (name == "camera_android_camerax" || name == "camera_android") {
        plugins.withId("com.android.library") {
            dependencies.add(
                "implementation",
                "androidx.concurrent:concurrent-futures:1.2.0",
            )
        }
    }
}



tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
