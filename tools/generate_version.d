import std.file : exists, mkdirRecurse, readText, write;
import std.exception : enforce;
import std.path : buildPath, buildNormalizedPath, dirName;
import std.process : execute, env = environment;
import std.string : strip;

enum rootDirectory = __FILE_FULL_PATH__.dirName.buildNormalizedPath("..");
enum outputDirectory = rootDirectory.buildPath("tmp");
enum versionFile = "version";

void main()
{
    mkdirRecurse(outputDirectory);

    outputDirectory
        .buildPath(versionFile)
        .updateIfChanged(generateVersion);
}

string generateVersion()
{
    const args = [
        "git",
        "-C", rootDirectory,
        "describe",
        "--dirty",
        "--tags",
        "--always"
    ];

    const result = execute(args);
    enforce(result.status == 0, "Failed to execute 'git describe'");

    return result.output.strip;
}

void updateIfChanged(const string path, const string content)
{
    const existingContent = path.exists ? path.readText : "";

    if (content != existingContent)
        write(path, content);
}
