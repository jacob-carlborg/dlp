module dlp.driver.command;

import dlp.core.optional : Optional;

mixin template StandardArguments()
{
    @("import-path|i", "Add <path> as an import path.")
    string[] importPaths;

    @("string-import-path", "Add <path> as a string import path.")
    string[] stringImportPaths;

    @("version", "Specify <version> version identifier.")
    string[] versionIdentifiers;
}

abstract class BaseCommand
{
    abstract string name() const;
    abstract string shortHelp() const;
    abstract string usageHeader() const;

    // Not part of the public API.
    abstract bool _run(string[] rawArgs) const;
}

abstract class Command(Arguments = void) : BaseCommand
{
    static if (is(Arguments == void))
        abstract void run(const string[] remainingArgs) const;
    else
        abstract void run(ref Arguments args, const string[] remainingArgs) const;

    override bool _run(string[] rawArgs) const
    {
        static if (is(Arguments == void))
            run(rawArgs[1 .. $]);
        else
        {
            import std.format : format;
            import dlp.driver.cli : parseCommandLine, printHelp;

            static if (is(Arguments : Object))
                auto arguments = new Arguments;
            else
                Arguments arguments;

            auto result = parseCommandLine(rawArgs, arguments);

            if (result.helpWanted)
            {
                const header = format!"Usage: dlp %s %s"(name, usageHeader);
                printHelp(header, arguments, result);
                return true;
            }

            run(arguments, rawArgs[1 .. $]);
        }

        return true;
    }

    Optional!string longHelp() const
    {
        import dlp.core.optional : none;

        return none!string;
    }
}
