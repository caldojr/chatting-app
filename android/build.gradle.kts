<<<<<<< HEAD
plugins {
       id("com.google.gms.google-services") 

}

=======
>>>>>>> 27551880ef1e78ecbb749df6558c3623fc9ec7d8
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

<<<<<<< HEAD
=======
plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
}

>>>>>>> 27551880ef1e78ecbb749df6558c3623fc9ec7d8
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
<<<<<<< HEAD

=======
>>>>>>> 27551880ef1e78ecbb749df6558c3623fc9ec7d8
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
