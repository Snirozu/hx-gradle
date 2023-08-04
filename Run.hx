import sys.io.File;
import haxe.io.Path;
import sys.FileSystem;

using StringTools;

function main() {
	final libPath = Sys.getCwd();
	var args = Sys.args();
	final projectPath = args[args.length - 1];
	Sys.setCwd(projectPath);
	args.pop();
    var gradleProjectPath = "gradle_project";
	if (FileSystem.exists("gradle_project.txt")) {
		gradleProjectPath = File.getContent("gradle_project.txt").trim();
    }

	var batchExt = Sys.systemName() == "Windows" ? ".bat" : ""; 

	if (args.length <= 0 || args[0] == "help") {
		echo("======= HaxeGradle =======", ANSI_GREEN);
		echo("> hxgradle readme - Please read this before using build command.");
		echo("> hxgradle build - Build the project using build.hxml file.");
		echo("> hxgradle update - Installs dependencies into 'dependencies' directory so you can use it with Haxe. " + 
				"Remember to add '--java-lib dependencies' to your build.hxml file after it finishes!");
        return;
	}

	switch (args[0]) {
		case "build":
			echo("Compiling...");
			var buildHXML = File.getContent("build.hxml");
			if (!buildHXML.contains("--java ")) {
				buildHXML += "\n--java " + gradleProjectPath + "/";
				File.saveContent("build.hxml", buildHXML);
			}
			else {
				var finalHXML = "";
				var javaTargetIndex = buildHXML.indexOf("--java ");
				for (i in 0...buildHXML.length) {
					var char = buildHXML.charAt(i);
					if (i >= javaTargetIndex && char == "\n") {
						javaTargetIndex = buildHXML.length;
						continue;
					}
					if (i >= javaTargetIndex) {
						continue;
					}
					finalHXML += char;
				}
				finalHXML += "--java " + gradleProjectPath + "/";
				File.saveContent("build.hxml", finalHXML);
			}
			Sys.command("haxe", ["build.hxml"]);

			if (!FileSystem.exists(gradleProjectPath + "/")) {
				echo("Failed!", ANSI_RED);
				return;
			}
			
			echo("Cleaning...");
			var jarName = gradleProjectPath;
			var classPath = gradleProjectPath;
			if (FileSystem.exists(gradleProjectPath + "/manifest")) {
				classPath = File.getContent(gradleProjectPath + "/manifest").split("\n")[0].split("Main-Class: ")[1].trim();
				jarName = classPath.split(".").pop().trim();
				final cleanList = ["obj/", "cmd", "hxjava_build.txt", "manifest"];
				for (file in cleanList) {
					removeFile(Path.join([gradleProjectPath + "/", file]));
				}
			}
			removeFile(gradleProjectPath + "/" + jarName + ".jar");

			if (!FileSystem.exists(gradleProjectPath + "/gradle/wrapper/gradle-wrapper.jar")) {
				echo("Copying Gradle Wrapper JAR...");
				FileSystem.createDirectory(gradleProjectPath + "/gradle/wrapper");
				File.copy(Path.join([libPath, "gradle/wrapper/gradle-wrapper.jar"]), gradleProjectPath + "/gradle/wrapper/gradle-wrapper.jar");
				File.copy(Path.join([libPath, "gradle/wrapper/gradle-wrapper.properties"]), gradleProjectPath + "/gradle/wrapper/gradle-wrapper.properties");
			}
			if (!FileSystem.exists(gradleProjectPath + "/gradlew" + batchExt)) {
				echo("Copying Gradle Wrapper...");
				File.copy(Path.join([libPath, "gradle/gradlew" + batchExt]), gradleProjectPath + "/gradlew" + batchExt);
			}
			if (!FileSystem.exists(gradleProjectPath + "/build.gradle")) {
				echo("Generating empty build.gradle file...");
				//File.copy(Path.join([libPath, "gradle/build.gradle"]), "build/build.gradle");
				var daGradleConfig = File.getContent(Path.join([libPath, "gradle/build.gradle"]));
				daGradleConfig = daGradleConfig.replace("%HXGRADLE_CLASS_PATH%", classPath);
				File.saveContent(gradleProjectPath + "/build.gradle", daGradleConfig);
			}

			echo("Executing gradle 'build' task...");
			Sys.setCwd(Path.join([projectPath, gradleProjectPath]));
			Sys.command("./gradlew" + batchExt, ["build"]);

			echo("Done!", ANSI_GREEN);

        case "readme":
			echo("Build command generates a gradle project in 'gradle_project' directory by default.");
			echo("This can be changed by writing the 'gradle_project.txt' file (in the root path) content to some other name.");
			echo("This library uses root project's `build.hxml` file's settings and compiles the code to `java` target.");
			echo("By default, the 'build.gradle' uses the Gradle Shadow Plugin to add dependencies inside the generated JAR.");
			echo("If you don't know where is the generated JAR file, it should be in build/libs directory inside the `gradle_project`");
			echo("Also you should have Java installed if it wasn't obvious.");
			echo("WARNING This library is experimental.");

		case "update":
			var daGradleConfig = File.getContent(Path.join([gradleProjectPath, "/build.gradle"]));
			if (!daGradleConfig.contains("task copyDependencies")) {
				echo("Generating missing 'copyDependencies' task");
				daGradleConfig += "\n\n" + File.getContent(Path.join([libPath, "gradle/copyDependencies.task"]));
				File.saveContent(Path.join([gradleProjectPath, "/build.gradle"]), daGradleConfig);
			}

			echo("Updating missing libraries...");
			Sys.setCwd(Path.join([projectPath, gradleProjectPath]));
			Sys.command("./gradlew" + batchExt, ["copyDependencies"]);

			echo("Done!", ANSI_GREEN);

        default:
            echo("Try 'hxgradle help'", ANSI_WHITE);
	}
}

final ANSI_RESET = "\u001B[0m";
final ANSI_BLACK = "\u001B[30m";
final ANSI_RED = "\u001B[31m";
final ANSI_GREEN = "\u001B[32m";
final ANSI_YELLOW = "\u001B[33m";
final ANSI_BLUE = "\u001B[34m";
final ANSI_PURPLE = "\u001B[35m";
final ANSI_CYAN = "\u001B[36m";
final ANSI_WHITE = "\u001B[37m";

function echo(s, color = "\u001B[33m") {
	Sys.println(color + s + ANSI_RESET);
}

function removeFile(path:String) {
	if (FileSystem.isDirectory(path)) {
		var list = FileSystem.readDirectory(path);
		for (it in list) {
			removeFile(Path.join([path, it]));
		}
		FileSystem.deleteDirectory(path);
	} else {
		FileSystem.deleteFile(path);
	}
}
