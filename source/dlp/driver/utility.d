module dlp.driver.utility;

import dmd.globals : Loc;

class MissingArgumentException : Exception
{
    this(
        string msg,
        string file = __FILE__,
        size_t line = __LINE__,
        Throwable nextInChain = null
    ) pure nothrow @nogc @safe
    {
        super(msg, file, line, nextInChain);
    }

    this(
        string msg,
        Throwable nextInChain,
        string file = __FILE__,
        size_t line = __LINE__
    ) pure nothrow @nogc @safe
    {
        super(msg, file, line, nextInChain);
    }
}

string toString(const ref Loc location) pure
{
    import std.format : format;
    import std.string : fromStringz;

    return format!"%s:%s:%s"(
        location.filename.fromStringz,
        location.linnum,
        location.charnum
    );
}
