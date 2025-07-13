plugins {
    id("pandaspigot.conventions")
    id("paperclip")
    id("com.gradleup.shadow") version "9.0.0-beta7"
}

dependencies {
    implementation("io.sigpipe:jbsdiff:1.0")
}

sourceSets {
    create("java9")
}

tasks {
    jar {
        archiveClassifier.set("original")
        manifest {
            val agentClass = "com.hpfxd.pandaspigot.paperclip.Agent"
            attributes(
                "Main-Class" to "com.hpfxd.pandaspigot.paperclip.Paperclip",
                "Multi-Release" to true,
                "Launcher-Agent-Class" to agentClass,
                "Premain-Class" to agentClass,
            )
        }
    }

    shadowJar {
        val prefix = "com.hpfxd.pandaspigot.paperclip.libs"
        arrayOf("org.apache", "org.tukaani", "io.sigpipe").forEach { pack ->
            relocate(pack, "$prefix.$pack")
        }

        exclude("META-INF/LICENSE.txt")
        exclude("META-INF/NOTICE.txt")

        into("META-INF/versions/9") {
            from(sourceSets["java9"].output)
        }

        from(file("license.txt")) {
            into("META-INF/license")
            rename { "paperclip-LICENSE.txt" }
        }
    }
}

// create task sendToNodes
tasks.register<Exec>("deployPluginToNodes") {
    group = "deployment"
    description = "Envia o plugin via SFTP e substitui nas nodes do Pterodactyl"

    // Passa o nome como argumento para o script
    commandLine("bash", "./scripts/send-to-nodes.sh", "paperclip.jar")
}
