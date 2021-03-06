module dlp.driver.commands.dlp_command;

import dlp.driver.command : Command;

mixin template StandardArguments()
{
    import dmd.target : Target;

    @("import-path|i", "Add <path> as an import path.")
    string[] importPaths;

    @("string-import-path", "Add <path> as a string import path.")
    string[] stringImportPaths;

    @("version", "Specify <version> version identifier.")
    string[] versionIdentifiers;

    @("config", "Use <filename> as the configuration file.")
    string configFilename;

    @("target-architecture", "Set <arch> as the target architecture [default].")
    Target.Architecture architecture;
}

abstract class DlpCommand(Arguments) : Command!Arguments
{
    protected override void beforeCommandLineParsing(string[] rawArgs)
    {
		static struct TempConfig
        {
            import dlp.commands.utility : StandardConfig;
            mixin StandardConfig;
        }

        arguments.architecture = TempConfig().architecture;
    }

    protected override void afterCommandLineParsing(string[] remainingArgs)
    {
        import dmd.frontend : findConfigFilename;

        if (arguments.configFilename.length == 0)
            arguments.configFilename = findConfigFilename();
    }
}
