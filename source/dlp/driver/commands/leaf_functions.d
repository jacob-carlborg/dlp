module dlp.driver.commands.leaf_functions;

import dlp.commands.leaf_functions : Config;
import dlp.driver.command : Command, StandardArguments;

struct Arguments
{
    mixin StandardArguments;
}

class LeafFunctions : Command!(Arguments)
{
    import dmd.func : FuncDeclaration;

    import dlp.core.optional : Optional, some;

    override string name() const
    {
        return "leaf-functions";
    }

    override string shortHelp() const
    {
        return "Prints all leaf functions.";
    }

    override string usageHeader() const
    {
        return "[options] <input>";
    }

    override Optional!string longHelp() const
    {
        return some("Prints all leaf functions to standard out. A leaf function " ~
            "is a function that doesn't call any other functions, or doesn't " ~
            "have a body.");
    }

    override void run(ref Arguments args, const string[] remainingArgs) const
    {
        import std.algorithm : each, map, sort;
        import std.array : array, empty;
        import std.file : readText;
        import std.exception : enforce;
        import std.typecons : tuple;

        import dlp.core.algorithm : flatMap;
        import dlp.driver.utility : MissingArgumentException;
        import dlp.commands.leaf_functions : leafFunctions;

        alias sortByLine = (a, b) => a.location.linnum < b.location.linnum;
        alias sortByColumn = (a, b) => a.location.charnum < b.location.charnum;

        enforce!MissingArgumentException(!remainingArgs.empty,
            "No input files were given");

        remainingArgs
            .map!(e => tuple(e, readText(e)))
            .flatMap!(e => leafFunctions(e.expand, args.toConfig)[])
            .map!toLeafFunction
            .array
            .sort!sortByLine
            .sort!sortByColumn // we sort by column since there can be multiple functions on the same line
            .each!printResult;
    }

    static LeafFunction toLeafFunction(FuncDeclaration func)
    {
        import dlp.commands.utility : fullyQualifiedName;

        return LeafFunction(func.loc, func.fullyQualifiedName);
    }

    static void printResult(LeafFunction leafFunction)
    {
        import std.stdio : writeln;

        writeln(leafFunction);
    }
}

Config toConfig(ref Arguments args)
{
    Config config = {
        versionIdentifiers: args.versionIdentifiers,
        importPaths: args.importPaths,
        stringImportPaths: args.stringImportPaths
    };

    return config;
}

private struct LeafFunction
{
    import dmd.globals : Loc;

    Loc location;
    string fullyQualifiedName;

    string toString() const pure
    {
        import std.format : format;
        import dlp.driver.utility : toString;

        return format!"%s: %s"(location.toString, fullyQualifiedName);
    }
}

version (unittest):

import dlp.core.test;

@test("no arguments") unittest
{
    import std.exception : assertThrown;
    import dlp.driver.utility : MissingArgumentException;

    Arguments arguments;
    string[] inputFiles = [];

    assertThrown!MissingArgumentException(
        new LeafFunctions().run(arguments, inputFiles)
    );
}
