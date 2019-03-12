module dlp.driver.commands.leaf_functions;

import dlp.driver.command : Command;

class LeafFunctions : Command!()
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

    override Optional!string longHelp() const
    {
        return some("Prints all leaf functions to standard out. A leaf function " ~
            "is a function that doesn't call any other functions, or doesn't " ~
            "have a body.");
    }

    override void run(const string[] remainingArgs) const
    {
        import std.algorithm : each, map, sort;
        import std.array : array;
        import std.file : readText;
        import std.typecons : tuple;

        import dlp.core.algorithm : flatMap;
        import dlp.visitors.leaf_functions : leafFunctions;

        alias sortByLine = (a, b) => a.location.linnum < b.location.linnum;
        alias sortByColumn = (a, b) => a.location.charnum < b.location.charnum;

        remainingArgs
            .map!(e => tuple(e, readText(e)))
            .flatMap!(e => leafFunctions(e.expand)[])
            .map!toLeafFunction
            .array
            .sort!sortByLine
            .release
            .sort!sortByColumn // we sort by column since there can be multiple functions on the same line
            .each!printResult;
    }

    static LeafFunction toLeafFunction(FuncDeclaration func)
    {
        import dlp.visitors.utility : fullyQualifiedName;

        return LeafFunction(func.loc, func.fullyQualifiedName);
    }

    static void printResult(LeafFunction leafFunction)
    {
        import std.string : fromStringz;
        import std.stdio : writefln;

        const location = leafFunction.location.toChars.fromStringz;
        writefln("%s: %s", location, leafFunction.fullyQualifiedName);
    }
}

private struct LeafFunction
{
    import dmd.globals : Loc;

    Loc location;
    string fullyQualifiedName;
}
