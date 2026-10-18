plugins {
    kotlin("jvm") version "2.4.21"
    id("org.jlleitschuh.gradle.ktlint") version "14.2.0"
    application
}

repositories {
    mavenCentral()
}

dependencies {
    testImplementation(kotlin("test"))
    testImplementation(platform("org.junit:junit-bom:6.1.3"))
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

kotlin {
    jvmToolchain(25)
    compilerOptions {
        allWarningsAsErrors = true
    }
}

ktlint {
    version = "1.8.0"
}

application {
    mainClass = "raytracer.MainKt"
}

tasks.test {
    useJUnitPlatform()
}

// Mirrors BenchmarkRender in the Go version: the test scene at 100x100 with 50
// samples per pixel. Usage: ./gradlew bench [--args="iterations threads"]
tasks.register<JavaExec>("bench") {
    description = "Times renders of the test scene."
    classpath = sourceSets.test.get().runtimeClasspath
    mainClass = "raytracer.BenchKt"
}
