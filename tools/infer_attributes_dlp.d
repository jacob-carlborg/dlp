#!/usr/bin/env dmd -Isource -run

import std.algorithm;
import std.array;
import std.file : dirEntries, SpanMode;
import std.parallelism : parallel;
import std.path;
import std.range;
import std.stdio;
import std.string;

import dlp.core.algorithm : flatMap;

enum projectRoot = __FILE_FULL_PATH__.dirName.buildNormalizedPath("..");
enum dlpSoucePath = projectRoot.buildPath("source");
enum dlpToolsPath = projectRoot.buildPath("tools");

immutable dlpArgs = [
    projectRoot.buildPath("dlp"),
    "infer-attributes",
    "--version", "NoBackend",
    "--version", "GC",
    "--version", "NoMain",
    "--version", "MARS"
];

string execute(string[] args ...) @safe
{
    static import std.process;

    const result = std.process.execute(args);

    if (result.status != 0)
    {
        const msg = format!"The command '%s' failed with error:\n%s"(args.join(" "),
            result.output);
        throw new Exception(msg);
    }

    return result.output;
}

int main()
{
    alias dubDescribe = flag => execute("dub", "describe", flag, "--verror");

    alias stringImportPathsFlags = () =>
        dubDescribe("--string-import-paths")
        .lineSplitter
        .flatMap!(e => ["--string-import-path", e]);

    alias importPathsFlags = () =>
        dubDescribe("--import-paths")
        .lineSplitter
        .flatMap!(e => ["-i", e]);

    auto args = dlpArgs
        .chain(importPathsFlags())
        .chain(stringImportPathsFlags());

    auto output = dirEntries(dlpSoucePath, "*.d", SpanMode.breadth)
        .chain(dirEntries(dlpToolsPath, "*.d", SpanMode.breadth))
        .map!(e => e.name.only)
        .map!(e => args.chain(e).array.execute)
        .filter!(e => !e.empty);

    const exitCode = !output.empty;
    output.each!writeln;

    return exitCode;
}
