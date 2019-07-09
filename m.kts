#!/usr/bin/env kotlinc -script
import java.io.File

fun exit(message: String = "Terminating build") {
    System.err.println(message)
    System.exit(0)
}

fun tryOrExit(fn: () -> Unit) {
    try {
        fn()
    } catch (e: Exception) {
        e.printStackTrace()
        exit()
    }
}

fun exec(string: String, file: File = File(".")) {
    val exec = ProcessBuilder(string.split(' ').toList())
            .redirectErrorStream(true)
            .inheritIO().directory(file.absoluteFile).start()
    val code = exec.waitFor()
    if (code != 0) exit("Command $string failed with exit code $code")
}

fun execM(args: String, string: String = "", file: File = File(".")) {
    val exec = ProcessBuilder("java -classpath ${bin.absolutePath}${File.pathSeparator}${mJvmJar.absolutePath} -Xss1g m $args".split(' ').toList())
            .redirectError(ProcessBuilder.Redirect.INHERIT)
            .redirectOutput(ProcessBuilder.Redirect.INHERIT)
            .directory(file.absoluteFile).start()
    if (string != "") {
        exec.outputStream.write("$string\n\n".toByteArray())
        exec.outputStream.flush()
    }
    val code = exec.waitFor()
    if (code != 0) exit("Command $string failed with exit code $code")
}

tailrec fun ask(message: String, yes: () -> Unit) {
    print("$message [y/n]: ")
    System.out.flush()
    val line = readLine()?.toLowerCase()?.trim() ?: "n"
    when (line) {
        "y", "yes" -> yes()
        "n", "no" -> exit()
        else -> {
            println("Expected [y/n]")
            ask(message, yes)
        }
    }
}

val bin = File("./bin")
val mStdlib = File("../m-stdlib")
val mJvm = File("../m-jvm")
val mJvmJar = File(mJvm, "build/libs/m-jvm-0.1.0.jar")

fun mCompile(backend: String, input: String, output: String) {
    println("Compiling $input to $backend")
    execM("compile $backend $input $output")
}

fun mJvmCompile(input: String, output: String) {
    println("Compiling $input with m-jvm")
    exec("java -classpath $mJvmJar -Xss4m io.github.m.Compiler $input $output")
}

fun help() {
    println("""
        m.kts help       -- Displays this help message
        m.kts build      -- Builds the M compiler
        m.kts build-full -- Builds the M compiler with itself
          m.kts build-backend      -- Builds the M backend
          m.kts build-host-backend -- Builds the M compiler host with the backend compiler
          m.kts build-host         -- Builds the M compiler host
          m.kts build-self         -- Builds the M compiler
          m.kts build-host-src     -- Builds the M compiler host's source
        m.kts clean      -- Cleans the M compiler
    """.trimIndent())
}

fun build() {
    buildBackend()
    buildHostBackend()
    buildHost()
    buildSelf()
}

fun buildFull() {
    clean()
    buildBackend()
    buildHostBackend()
    buildHost()
    buildHost()
    buildSelf()
    buildSelf()
    buildHostSrc()
}

fun buildBackend() {
    if (!mJvm.exists()) {
        val mJvmGit = "https://github.com/m-language/m-jvm.git"
        ask("$mJvm does not exist, would you like to clone it from $mJvmGit?") {
            exec("git clone $mJvmGit", File(".."))
        }
    }

    exec("gradle fatJar", mJvm)
}

fun buildHostBackend() {
    mJvmCompile("m.m", bin.path)
}

fun buildHost() {
    mCompile("jvm", "m.m", bin.path)
}

fun buildSelf() {
    mCompile("jvm", "src", bin.path)
}

fun buildHostSrc() {
    mCompile("m", "src", "m.m")
}

fun clean() {
    println("Removing bin")
    bin.deleteRecursively()
}

fun m() {
    val args = args.joinToString(separator = " ", prefix = "", postfix = "")
    val exec = ProcessBuilder("java -classpath ./bin${File.pathSeparator}$mJvmJar -Xss1g m $args".split(' ').toList()).inheritIO().start()
    val code = exec.waitFor()
    if (code != 0) exit("m failed with exit code $code")
}

when (args[0]) {
    "help" -> help()
    "build" -> build()
    "build-full" -> buildFull()
    "build-backend" -> buildBackend()
    "build-host-backend" -> buildHostBackend()
    "build-host" -> buildHost()
    "build-self" -> buildSelf()
    "build-host-src" -> buildHostSrc()
    "clean" -> clean()
    else -> m()
}