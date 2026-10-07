#!/usr/bin/env python3
"""يدمج تعديلات Gradle (desugaring + محاذاة JVM) في خطوة واحدة. آمن للتكرار."""
import pathlib

# --- 1) core library desugaring ---
kts = pathlib.Path('android/app/build.gradle.kts')
groovy = pathlib.Path('android/app/build.gradle')
if kts.exists():
    path = kts
    content = path.read_text()
    if 'isCoreLibraryDesugaringEnabled' not in content:
        content = content.replace(
            'compileOptions {',
            'compileOptions {\n        isCoreLibraryDesugaringEnabled = true',
            1
        )
    if 'coreLibraryDesugaring(' not in content:
        if 'dependencies {' in content:
            content = content.replace(
                'dependencies {',
                'dependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")',
                1
            )
        else:
            content += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    path.write_text(content)
else:
    path = groovy
    content = path.read_text()
    if 'coreLibraryDesugaringEnabled' not in content:
        content = content.replace(
            'compileOptions {',
            'compileOptions {\n        coreLibraryDesugaringEnabled true',
            1
        )
    if 'coreLibraryDesugaring ' not in content:
        if 'dependencies {' in content:
            content = content.replace(
                'dependencies {',
                "dependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'",
                1
            )
        else:
            content += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    path.write_text(content)

# --- 2) Kotlin JVM targets ---
kts = pathlib.Path('android/build.gradle.kts')
groovy = pathlib.Path('android/build.gradle')
if kts.exists():
    path = kts
    content = path.read_text()
    marker = 'JvmTarget.JVM_17'
    if marker not in content:
        content = '''import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

''' + content
        content += '''

// Match Android plugin Java targets; flutter_timezone still targets Java 11.
subprojects {
    tasks.withType<KotlinCompile>().configureEach {
        if (project.name == "flutter_timezone") {
            compilerOptions.jvmTarget.set(JvmTarget.JVM_11)
        } else {
            compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}
'''
        path.write_text(content)
elif groovy.exists():
    path = groovy
    content = path.read_text()
    marker = 'kotlinOptions.jvmTarget = "17"'
    if marker not in content:
        content += '''

// Match Android plugin Java targets; flutter_timezone still targets Java 11.
subprojects {
    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile).configureEach {
        kotlinOptions.jvmTarget = project.name == "flutter_timezone" ? "11" : "17"
    }
}
'''
        path.write_text(content)
