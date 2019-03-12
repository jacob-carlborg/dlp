module dlp.driver.application;

import std.array;
import std.stdio;

import dlp.driver.cli;
import dlp.core.optional;

enum ExitStatus
{
    success,
    fail,
    stop
}

class Application
{
    import std.string : strip;
    import std.range : drop;

    import dlp.driver.command : BaseCommand;

    enum version_ = import("version").strip.drop(1);

    static final class ParsedArguments : .ParsedArguments
    {
        bool version_;
        bool help;

        Optional!string command;
        string[] remainingArgs;

        this(Optional!string command = none!string, string[] remainingArgs = [])
        {
            this.command = command;
            this.remainingArgs = remainingArgs;
        }
    }

    private string[] args;
    private BaseCommand[string] commands;

    static int start(string[] args)
    {
        return new Application(args).run();
    }

    this(string[] args)
    in
    {
        assert(!args.empty);
    }
    do
    {
        this.args = args;

        registerCommands();
    }

private:

    int run()
    {
        import std.stdio : stderr;
        import std.array : empty;

        import dlp.visitors.utility : DiagnosticsException;

        try
            return runImplementation() ? 0 : 1;
        catch (DiagnosticsException)
        {
            // For DiagnosticsException the errors have already been printed
        }
        catch (Throwable t)
            stderr.writeln(t.message);

        return 1;
    }

    bool runImplementation()
    {
        import dlp.driver.commands.leaf_functions : LeafFunctions;

        registerCommands();
        auto parsedArguments = parseCli();

        const result = handleArguments(parsedArguments);

        if (result == ExitStatus.fail)
            return false;

        if (result == ExitStatus.success)
            return invokeCommand(parsedArguments.command.get,
                parsedArguments.remainingArgs);

        return true;
    }

    bool invokeCommand(const string command, string[] args)
    {
        import std.format : format;

        if (auto invoker = command in commands)
            return (*invoker)._run(args);
        else
            throw new CliException(format!`Unrecognized command "%s"`(command));
    }

    void registerCommands()
    {
        import dlp.driver.commands.leaf_functions : LeafFunctions;

        registerCommand!LeafFunctions;
    }

    void registerCommand(Command)()
    {
        auto command = new Command();
        commands[command.name] = command;
    }

    ParsedArguments parseCli()
    {
        import std.typecons : tuple;

        static ParsedArguments parseGlobalCLi(string[] args)
        {
            import std.getopt : getopt, defaultGetoptPrinter;

            auto parsedArguments = new ParsedArguments;

            auto result = getopt(args,
                "version|V", "Print the version of DLP and exit.", &parsedArguments.version_
            );

            parsedArguments.remainingArgs = args;
            parsedArguments.help = result.helpWanted;
            parsedArguments.getoptResult = result;

            return parsedArguments;
        }

        static auto parseCommand(string[] rawArgs) pure
        in
        {
            assert(rawArgs.length >= 1);
        }
        do
        {
            import std.algorithm : startsWith;
            import std.array : empty, front;
            import std.typecons : tuple;

            auto args = rawArgs[1 .. $];

            if (args.empty || args.front.startsWith("-"))
                return tuple(none!string, rawArgs);

            return tuple(some(args.front), args[1 .. $]);
        }

        auto t = parseCommand(args);

        if (t[0].isPresent)
            return new ParsedArguments(t[0], t[1]);

        auto parsedArguments = parseGlobalCLi(t[1]);
        parsedArguments.command = t[0];
        parsedArguments.remainingArgs = t[1];

        return parsedArguments;
    }

    ExitStatus handleArguments(ParsedArguments parsedArguments)
    {
        import std.stdio : stderr;

        if (parsedArguments.help)
        {
            printHelp(parsedArguments);
            return ExitStatus.stop;
        }

        if (parsedArguments.version_)
        {
            printVersion();
            return ExitStatus.stop;
        }

        if (parsedArguments.command.empty)
        {
            stderr.writeln("No command specified");
            printHelp(parsedArguments);
            return ExitStatus.fail;
        }

        return ExitStatus.success;
    }

    void printVersion()
    {
        import std.stdio : writeln;
        writeln(version_);
    }

    void printHelp(ParsedArguments parsedArguments)
    {
        import std.format : format;
        import std.getopt : defaultGetoptPrinter;
        import std.stdio : writef;

        string generateCommandsHelp()
        {
            import std.algorithm : joiner, map, reduce, max;
            import std.conv : to;
            import std.format : format;
            import std.range : repeat;

            const maxLength = commands
                .byValue
                .map!(e => e.name.length)
                .array
                .reduce!max;

            alias formatCommand = e => format(
                "    %-*s %s\n", maxLength + 1, e.name, e.shortHelp
            );

            return commands
                .byValue
                .map!formatCommand
                .joiner("\n")
                .to!string;
        }

        enum helpBanner = q"BANNER
Usage: dlp [options] <command> [args]
Version: %s

Options:
BANNER".format(version_);

        defaultGetoptPrinter(helpBanner, parsedArguments.getoptResult.options);

        writef("\nCommands:\n%s", generateCommandsHelp());
    }
}

private class CliException : Exception
{
    @nogc @safe pure nothrow this(string msg, string file = __FILE__,
        size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, Throwable nextInChain,
        string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}
