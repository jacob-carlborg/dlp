#!/usr/bin/env dmd -run

import std.file : dirEntries, SpanMode;
import std.path;
import std.algorithm;
import std.stdio;
import std.process;
import std.range;
import std.array;

enum projectRoot = __FILE_FULL_PATH__.dirName.buildNormalizedPath("..");
enum dlpSoucePath = projectRoot.buildPath("source");

immutable dlpArgs = [
    projectRoot.buildPath("dlp"),
    "infer-attributes",
    "--version", "NoBackend",
    "--version", "GC",
    "--version", "NoMain",
    "--version", "MARS",
    "--string-import-path", projectRoot.buildPath("tmp"),
    "--string-import-path", projectRoot.buildPath("vendor", "dmd", "res"),
    "-i", projectRoot.buildPath("source"),
    "-i", projectRoot.buildPath("vendor", "dmd", "src")
];

void main()
{

    dirEntries(dlpSoucePath, "*.d", SpanMode.breadth);

    const args = dlpArgs ~ dlpSoucePath.buildPath("dlp/driver/application.d");
    auto result = execute(dlpArgs ~ dlpSoucePath.buildPath("dlp/driver/application.d"));

    if (result.status != 0)
        throw new Exception("error:\n" ~ result.output);

    if (!result.output.empty)
        throw new Exception("output:\n" ~ result.output);
}
