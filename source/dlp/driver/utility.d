module dlp.driver.utility;

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
