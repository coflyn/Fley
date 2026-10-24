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

subprojects {
    val configureProject = Action<Project> {
        if (plugins.hasPlugin("com.android.library")) {
            val android = extensions.findByName("android")
            if (android != null) {
                try {
                    val getNamespace = android.javaClass.getMethod("getNamespace")
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    if (getNamespace.invoke(android) == null) {
                        // Dynamically extract the package attribute from AndroidManifest.xml
                        val manifestFile = file("${project.projectDir}/src/main/AndroidManifest.xml")
                        var packageName: String? = null
                        if (manifestFile.exists()) {
                            val manifestContent = manifestFile.readText()
                            val match = Regex("package=\"([^\"]+)\"").find(manifestContent)
                            if (match != null) {
                                packageName = match.groupValues[1]
                            }
                        }
                        
                        // Fallback to name if not found in manifest
                        val finalPackage = packageName ?: "com.fley.${project.name.replace("-", "_").replace(".", "_")}"
                        setNamespace.invoke(android, finalPackage)
                    }
                    
                    // Force compileSdkVersion to 36 for modern dependencies via advanced reflection
                    for (method in android.javaClass.methods) {
                        if (method.name == "setCompileSdk" || method.name == "compileSdkVersion") {
                            try {
                                if (method.parameterTypes.size == 1) {
                                    val paramType = method.parameterTypes[0]
                                    if (paramType == Int::class.javaPrimitiveType || paramType == java.lang.Integer::class.java || paramType == String::class.java) {
                                        if (paramType == String::class.java) {
                                            method.invoke(android, "android-36")
                                        } else {
                                            method.invoke(android, 36)
                                        }
                                    }
                                }
                            } catch (e2: Exception) {
                                // Fail-silent
                            }
                        }
                    }
                    

                } catch (e: Exception) {
                    // Fail-silent
                }
            }
        }
    }
    
    if (state.executed) {
        configureProject.execute(this)
    } else {
        afterEvaluate {
            configureProject.execute(this)
        }
    }
}

subprojects {
    tasks.whenTaskAdded {
        val task = this
        val hasKotlinOptions = try { task.javaClass.getMethod("getKotlinOptions"); true } catch (e: Throwable) { false }
        val hasCompilerOptions = try { task.javaClass.getMethod("getCompilerOptions"); true } catch (e: Throwable) { false }
        
        if (hasKotlinOptions || hasCompilerOptions) {
            var targetVersion = "17"
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                    val resolvedCompatibility = compileOptions.javaClass.getMethod("getTargetCompatibility").invoke(compileOptions)
                    var ver = resolvedCompatibility.toString()
                    if (ver == "1.8") ver = "8"
                    else if (ver.startsWith("1.")) ver = ver.substring(2)
                    targetVersion = ver
                } catch (e: Throwable) {
                    // Fallback
                }
            }
            
            try {
                val compilerOptions = task.javaClass.getMethod("getCompilerOptions").invoke(task)
                val jvmTargetProp = compilerOptions.javaClass.getMethod("getJvmTarget")
                val property = jvmTargetProp.invoke(compilerOptions)
                val jvmTargetClass = Class.forName("org.jetbrains.kotlin.gradle.dsl.JvmTarget")
                val fromTargetMethod = jvmTargetClass.getMethod("fromTarget", String::class.java)
                val jvmTargetEnum = fromTargetMethod.invoke(null, targetVersion)
                property.javaClass.getMethod("set", Any::class.java).invoke(property, jvmTargetEnum)
                println("SYNC_SUCCESS: Dynamic compilerOptions set to $targetVersion for task ${task.name} in project ${project.name}")
            } catch (e: Throwable) {
                try {
                    val kotlinOptions = task.javaClass.getMethod("getKotlinOptions").invoke(task)
                    kotlinOptions.javaClass.getMethod("setJvmTarget", String::class.java).invoke(kotlinOptions, targetVersion)
                    println("SYNC_SUCCESS: Dynamic kotlinOptions set to $targetVersion for task ${task.name} in project ${project.name}")
                } catch (e2: Throwable) {
                    // Silent
                }
            }
        }
        
        if (task is JavaCompile) {
            var targetVersion = "17"
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                    val resolvedCompatibility = compileOptions.javaClass.getMethod("getTargetCompatibility").invoke(compileOptions)
                    var ver = resolvedCompatibility.toString()
                    if (ver == "1.8") ver = "8"
                    else if (ver.startsWith("1.")) ver = ver.substring(2)
                    targetVersion = ver
                } catch (e: Throwable) {
                    // Fallback
                }
            }
            task.sourceCompatibility = targetVersion
            task.targetCompatibility = targetVersion
            println("SYNC_SUCCESS: JavaCompile set to $targetVersion for task ${task.name} in project ${project.name}")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
