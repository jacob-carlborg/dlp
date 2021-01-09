module dlp.driver.command;

import dlp.core.optional : Optional;

abstract class BaseCommand
{
    abstract string name() const;
    abstract string shortHelp() const;
    abstract string usageHeader() const;

    // Not part of the public API.
    bool start(string[] rawArgs)
    {
        beforeRun();
        return _run(rawArgs);
    }

    protected void beforeRun()
    {

    }

    // Not part of the public API.
    protected abstract bool _run(string[] rawArgs);
}

abstract class Command(Arguments = void) : BaseCommand
{
    static if (!is(Arguments == void))
        protected Arguments arguments;

    abstract void run(const string[] remainingArgs) const;

    protected override bool _run(string[] rawArgs)
    {
        static if (is(Arguments == void))
            run(rawArgs[1 .. $]);
        else
        {
            import std.format : format;
            import dlp.driver.cli : parseCommandLine, printHelp;

            auto result = parseCommandLine(rawArgs, arguments);

            if (result.helpWanted)
            {
                const header = format!"Usage: dlp %s %s"(name, usageHeader);
                printHelp(header, result);
                return true;
            }

            run(rawArgs[1 .. $]);
        }

        return true;
    }

    Optional!string longHelp() const
    {
        import dlp.core.optional : none;

        return none!string;
    }
}
