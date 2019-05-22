module dlp.driver.commands.infer_attributes;

import dlp.commands.infer_attributes : Config;
import dlp.driver.command : Command, StandardArguments;

struct Arguments
{
    mixin StandardArguments;

    @("include-virtual-methods", "Infer attributes for virtual methods [default].")
    bool includeVirtualMethods = Config.init.includeVirtualMethods;
}

class InferAttributes : Command!(Arguments)
{
    import dmd.func : FuncDeclaration;

    import dlp.core.optional : Optional, some;
    import dlp.commands.infer_attributes : Attributes;

    override string name() const
    {
        return "infer-attributes";
    }

    override string shortHelp() const
    {
        return "Prints the inferred attributes all functions";
    }

    override string usageHeader() const
    {
        return "[options] <input>";
    }

    override Optional!string longHelp() const
    {
        return some("Prints the inferred attributes of all non-templated " ~
            "functions. That is, the attributes that can be applied to the " ~
            "functions that are not already declared.");
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
        import dlp.commands.infer_attributes : inferAttributes;

        static bool sortByLocation(InferredAttributes a, InferredAttributes b)
        {
            if (a.location.linnum == b.location.linnum)
                return a.location.charnum < b.location.charnum;
            else
                return a.location.linnum < b.location.linnum;
        }

        enforce!MissingArgumentException(!remainingArgs.empty,
            "No input files were given");

        alias infer = e => inferAttributes(
            e.expand,
            args.toConfig
        ).byKeyValue;

        remainingArgs
            .map!(e => tuple(e, readText(e)))
            .flatMap!infer
            .map!(e => toInferredAttributes(e.key, e.value))
            .array
            .sort!sortByLocation
            .each!printResult;
    }

    static InferredAttributes toInferredAttributes(
        FuncDeclaration func, Attributes attributes
    )
    {
        import dlp.commands.utility : fullyQualifiedName;

        return InferredAttributes(func.loc, func.ident.toString, attributes);
    }

    static void printResult(InferredAttributes inferredAttributes)
    {
        import std.stdio : writeln;

        writeln(inferredAttributes);
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

private struct InferredAttributes
{
    import dmd.globals : Loc;

    import dlp.commands.infer_attributes : Attributes;

    Loc location;
    private const(char)[] name_;
    Attributes attributes;

    const(char)[] name() const pure nothrow @nogc @safe
    {
        import std.algorithm : startsWith;

        if (name_.startsWith("_staticCtor_"))
            return "static this";

        else if (name_.startsWith("_staticDtor_"))
            return "static ~this";

        else if (name_.startsWith("_sharedStaticCtor_"))
            return "shared static this";

        else if (name_.startsWith("_sharedStaticDtor_"))
            return "shared static ~this";

        switch (name_)
        {
            case "__ctor": return "this";
            case "__dtor": return "~this";
            default: return name_;
        }
    }

    string toString() const pure
    {
        import std.format : format;
        import dlp.driver.utility : toString;

        return format!"%s: %s: %s"(location.toString, name, attributes);
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
        new InferAttributes().run(arguments, inputFiles)
    );
}
