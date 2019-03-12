module dlp.driver.cli;

import std.getopt : GetoptResult;

import dlp.core.optional;

abstract class ParsedArguments
{
    GetoptResult getoptResult;
}

/**
 * Processes command-line arguments
 *
 * Params:
 *  rawArgs = the raw command-line arguments to parse
 *  arguments = where to parse the raw arguments into
 *
 *  Returns: getopt parse result
 */
GetoptResult parseCommandLine(Arguments)(string[] rawArgs, ref Arguments arguments)
{
    import std.getopt : getopt;

    return getopt(rawArgs, makeGetOptArgs!arguments);
}

void printHelp(Arguments)(
    const string header,
    const ref Arguments arguments,
    const GetoptResult getoptResult,
    Optional!string footer = none
)
{
    import std.stdio;
    import std.string;
    import std.range;
    import std.algorithm;

    struct Entry
    {
        import std.getopt : Option;

        string option;
        string help;

        this(string option, string help)
        {
            this.option = option;
            this.help = help;
        }

        this(Option option)
        {
            if (option.optShort && option.optLong)
                this.option = format("%s, %s", option.optShort, option.optLong);
            else if (option.optShort)
                this.option = option.optShort;
            else
                this.option = option.optLong;

            auto pair = findSplitAfter(option.help, "!");

            if (!pair[0].empty)
            {
                this.option ~= pair[0][0 .. $ - 1];
                this.help = pair[1];
            }
            else
            {
                this.help = option.help;
            }
        }
    }

    auto entries = getoptResult.options
        .filter!(option => !option.help.empty)
        .map!(option => Entry(option));

    auto maxLength = entries
        .map!(entry => entry.option.length)
        .array
        .reduce!max;

    auto helpString = appender!string();

    helpString.put(header);
    helpString.put("\n");

    if (!entries.empty)
        helpString.put("\nOptions:\n");

    entries
        .map!(e => format("    %-*s %s", maxLength + 1, e.option, e.help))
        .joiner("\n")
        .copy(helpString);

    footer.each!(e => helpString.put(e));
    writeln(helpString.data);
}


private:

template makeGetOptArgs(alias arguments)
{
    import std.meta;

    template expand(alias spelling)
    {
        alias member = Alias!(__traits(getMember, arguments, spelling));

        static if (
            __traits(compiles, &__traits(getMember, arguments, spelling)) &&
            __traits(getAttributes, member).length == 2)
        {
            auto ptr() @property
            {
                return &__traits(getMember, arguments, spelling);
            }

            auto formatHelp(alias spelling)(string help)
            {
                import std.algorithm;
                import std.format;
                import std.string;
                import std.range;

                string suffix;

                static if (is(typeof(member) == bool) || is(typeof(member) == enum))
                {
                    auto default_ = "[default]";

                    if (help.canFind(default_))
                    {
                        help = help.replace(
                            default_,
                            format("[default: %s]", __traits(getMember, arguments, spelling)));

                        static if (is(typeof(member) == bool))
                        {
                            suffix = "=true|false";
                        }
                        else
                        {
                            suffix = format(
                                "=%s",
                                join([ __traits(allMembers, typeof(member)) ], "|"));
                        }
                    }
                }
                else
                {
                    auto beginning = findSplitBefore(help, "<");

                    if (!beginning[0].empty)
                    {
                        auto placeholder = findSplitAfter(beginning[1], ">");

                        if (!placeholder[0].empty)
                            suffix = format(" %s", placeholder[0]);
                    }
                }

                return format("%s!%s", suffix, help);
            }

            alias expand = AliasSeq!(
                __traits(getAttributes, __traits(getMember, arguments, spelling))[0],
                formatHelp!spelling(
                    __traits(getAttributes, __traits(getMember, arguments, spelling))[1]),
                ptr);
        }
        else
        {
            alias expand = AliasSeq!();
        }
    }

    alias makeGetOptArgs = staticMap!(expand,
        __traits(allMembers, typeof(arguments))
    );
}

