plugins {
    java
}

repositories {
    mavenCentral()
}

val musicSdkAar by configurations.creating {
    isCanBeConsumed = false
    isCanBeResolved = true

    attributes {
        attribute(
            org.gradle.api.attributes.Category.CATEGORY_ATTRIBUTE,
            objects.named(org.gradle.api.attributes.Category.LIBRARY),
        )
        attribute(
            org.gradle.api.attributes.Usage.USAGE_ATTRIBUTE,
            objects.named(org.gradle.api.attributes.Usage.JAVA_RUNTIME),
        )
        attribute(
            org.gradle.api.attributes.LibraryElements.LIBRARY_ELEMENTS_ATTRIBUTE,
            objects.named("aar"),
        )
    }
}

dependencies {
    add("musicSdkAar", "io.github.quanghd96:MusicSDK:1.0.0")
}

tasks.register<Copy>("copyRuntimeArtifacts") {
    from(musicSdkAar)
    into(layout.buildDirectory.dir("artifacts"))
}
