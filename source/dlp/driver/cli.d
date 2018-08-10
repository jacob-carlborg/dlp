module dlp.driver.cli;

import std.getopt : GetoptResult;

abstract class ParsedArguments
{
    GetoptResult getoptResult;
}
