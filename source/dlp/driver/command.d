module dlp.driver.command;

import dlp.core.optional : Optional;

abstract class Command
{
    abstract string name() const;
    abstract string shortHelp() const;
    abstract void run(const string[] args) const;

    Optional!string longHelp() const
    {
        import dlp.core.optional : none;

        return none!string;
    }
}
