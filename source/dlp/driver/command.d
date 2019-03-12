module dlp.driver.command;

import dlp.core.optional : Optional;

abstract class BaseCommand
{
    abstract string name() const;
    abstract string shortHelp() const;

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
            run(rawArgs);
        else
        {
            import dlp.driver.cli : parseCommandLine, printHelp;

            Arguments arguments;
            auto result = parseCommandLine(rawArgs, arguments);

            if (result.helpWanted)
            {
                printHelp("Usage: dlp " ~ name, arguments, result);
                return true;
            }

            run(arguments, rawArgs);
        }

        return true;
    }

    Optional!string longHelp() const
    {
        import dlp.core.optional : none;

        return none!string;
    }
}
