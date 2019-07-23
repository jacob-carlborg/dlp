module dlp.driver.application;

import std.array;
import std.getopt : GetoptResult;
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

    private
    {
        bool verbose;
        string[] args;
        BaseCommand[string] commands;
    }

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

    static struct Arguments
    {
        @("version|V", "Print the version of DLP and exit.")
        bool version_;

        @("verbose|v", "Print verbose output.")
        bool verbose;

        @("frontend-version", "Print the version of the frontend DLP is using")
        bool frontendVersion;

        bool help;
        Optional!string command;
        string[] remainingArgs;
        GetoptResult getoptResult;

        this(Optional!string command, string[] remainingArgs)
        {
            this.command = command;
            this.remainingArgs = remainingArgs;
        }
    }

    int run()
    {
        import std.algorithm : canFind;
        import std.array : empty;
        import std.stdio : stderr;

        import dlp.commands.utility : DiagnosticsException;

        verbose = args.canFind("--verbose") || args.canFind("-v");

        try
            return runImplementation() ? 0 : 1;
        catch (DiagnosticsException)
        {
            // For DiagnosticsException the errors have already been printed
        }
        catch (Throwable t)
            stderr.writeln(verbose ? t.toString : t.message);

        return 1;
    }

    bool runImplementation()
    {
        import dlp.driver.commands.leaf_functions : LeafFunctions;

        registerCommands();
        auto arguments = parseCli();writeln(arguments.version_);
        const result = handleArguments(arguments);

        if (result == ExitStatus.fail)
            return false;

        if (result == ExitStatus.success)
            return invokeCommand(arguments.command.get, arguments.remainingArgs);

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
        import dlp.driver.commands.infer_attributes : InferAttributes;
        import dlp.driver.commands.leaf_functions : LeafFunctions;

        registerCommand!InferAttributes;
        registerCommand!LeafFunctions;
    }

    void registerCommand(Command)()
    {
        auto command = new Command();
        commands[command.name] = command;
    }

    Arguments parseCli()
    {
        import std.typecons : tuple;

        static Arguments parseGlobalCLi(string[] args)
        {
            enum CommandLineParsingConfig config = {
                passThrough: true,
                stopOnFirstNonOption: true
            };

            Arguments arguments;
            auto result = parseCommandLine!config(args, arguments);

            arguments.getoptResult = result;
            arguments.remainingArgs = args;
            arguments.help = result.helpWanted;

            return arguments;
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

            return tuple(some(args.front), rawArgs[0] ~ args[1 .. $]);
        }

        auto arguments = parseGlobalCLi(args);
        auto t = parseCommand(arguments.remainingArgs);
        arguments.command = t[0];
        arguments.remainingArgs = t[1];

        return arguments;
    }

    ExitStatus handleArguments(const ref Arguments arguments)
    {
        import std.stdio : stderr;

        if (arguments.help)
        {
            printHelp(arguments);
            return ExitStatus.stop;
        }

        if (arguments.version_)
        {
            printVersion();
            return ExitStatus.stop;
        }

        if (arguments.frontendVersion)
        {
            printFrontendVersion();
            return ExitStatus.stop;
        }

        if (arguments.command.empty)
        {
            stderr.writeln("No command specified");
            printHelp(arguments);
            return ExitStatus.fail;
        }

        return ExitStatus.success;
    }

    void printVersion()
    {
        import std.stdio : writeln;
        writeln(version_);
    }

    void printFrontendVersion()
    {
        import std.stdio : writeln;
        import std.string : fromStringz;
        import dmd.globals : global;

        global._init();
        scope(exit) global.deinitialize();

        writeln(global._version);
    }

    void printHelp(const ref Arguments arguments)
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
                "    %-*s %s", maxLength + 1, e.name, e.shortHelp
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
BANNER".format(version_).strip;

        .printHelp(
            helpBanner,
            arguments,
            arguments.getoptResult,
            some("\n\nCommands:\n" ~ generateCommandsHelp)
        );
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
