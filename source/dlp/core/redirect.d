module dlp.core.redirect;

import std.traits : isCallable;

@system:

RedirectContext redirect(alias from, alias to)()
    if (isCallable!from && isCallable!to)
{
    import std.array : join;
    import std.traits : Parameters, ReturnType;
    import std.meta : AliasSeq;

    import dlp.core.traits : hasThisReference, ThisType;

    static if (hasThisReference!from)
    {
        enum attributes = [__traits(getFunctionAttributes, from)].join(" ");
        alias NewParameters = AliasSeq!(Parameters!from, ThisType!from);
        mixin("alias NewType = ReturnType!from function(NewParameters) " ~ attributes ~ ";");

        static assert(is(typeof(&to) == NewType),
            `The target function "` ~ __traits(identifier, to) ~ `" of type "` ~
            typeof(to).stringof ~ `" needs to be of the same type as the ` ~
            `source function "` ~ __traits(identifier, from) ~ `" of the type "` ~
            typeof(*NewType.init).stringof ~ `"`);
    }

    else
        static assert(is(typeof(from) == typeof(to)),
            `The source "` ~ typeof(from).stringof ~ `" and target "` ~
            typeof(to).stringof ~ `" functions need to be of the same type`);

    return RedirectContext(&from, rawRedirect(&from, &to));
}

struct RedirectContext
{
    private void* sourceAddress;
    private const RedirectData contextData;

    void restore()
    {
        restoreRedirection(sourceAddress, contextData);
    }
}

unittest
{
    static int counter;

    static void increment()
    {
        counter++;
    }

    static void decrement()
    {
        counter--;
    }

    increment();
    assert(counter == 1);

    auto context = redirect!(increment, decrement);

    increment();
    assert(counter == 0);

    context.restore();

    increment();
    assert(counter == 1);
}

unittest
{
    class Expression
    {
        int counter;

        final void increment() pure nothrow @nogc @safe
        {
            counter++;
        }
    }

    static void decrement(Expression e) pure nothrow @nogc @safe
    {
        e.counter--;
    }

    scope exp = new Expression;

    exp.increment();
    assert(exp.counter == 1);

    auto context = redirect!(Expression.increment, decrement);

    exp.increment();
    assert(exp.counter == 0);

    context.restore();

    exp.increment();
    assert(exp.counter == 1);
}

private:

alias RedirectData = ubyte[6];

version (Posix)
    extern (C) int getpagesize();

RedirectData rawRedirect(void* from, void* to)
{
    // compute ASM
    ubyte[6] cmd;

    // // sanity checks
    if ((from <= to && to <= from + 5) || (to <= from && from <= to + 5))
    {
        return cmd;
        //throw new Exception("illegal source-destination combination");
    }

    cmd[0] = 0xE9; // jmp
    cmd[5] = 0xC3; // retn

    const offset = cast(int) (to - (from + 5));

    cmd[1 .. 1 + offset.sizeof] = (cast(ubyte*) &offset)[0 .. offset.sizeof];

    // save original
    ubyte[6] original = (cast(ubyte*)from)[0 .. cmd.length];

    // write asm
    procWrite(from, cmd);
    return original;
}

void restoreRedirection(void* address, const ref RedirectData data)
{
    procWrite(address, data);
}

void procWrite(void* pos, const ref RedirectData data)
{
    import core.stdc.string : memmove;

    version (Posix)
    {
        import core.sys.posix.sys.mman : mprotect, PROT_NONE, PROT_READ, PROT_WRITE, PROT_EXEC;

        enum readExecute = PROT_READ | PROT_EXEC;
        enum readExecuteWrite = readExecute | PROT_WRITE;
        enum oldProtect = readExecute;
    }
    else version (Windows)
    {
        import core.sys.windows.winbase : VirtualProtect;
        import core.sys.windows.windef : DWORD;
        import core.sys.windows.winnt : PAGE_EXECUTE_READ, PAGE_EXECUTE_READWRITE;

        enum readExecute = PAGE_EXECUTE_READ;
        enum readExecuteWrite = PAGE_EXECUTE_READWRITE;

        static int getpagesize()
        {
            import core.sys.windows.winbase : GetSystemInfo, SYSTEM_INFO;

            SYSTEM_INFO info;
            GetSystemInfo(&info);

            return info.dwPageSize;
        }

        static int mprotect(void* address, size_t length, int protection)
        {
            DWORD oldProtect;
            return VirtualProtect(address, length, protection, &oldProtect) != 0;
        }
    }

    void* addr = pos;
    size_t page = getpagesize();
    addr -= (cast(size_t)addr) % page;

    version (Posix)
    {
        if (mprotect(addr, page, readExecuteWrite) != 0)
            return; // error
    }
    else version (Windows)
    {
        DWORD oldProtect;
        if (!VirtualProtect(addr, page, readExecuteWrite, &oldProtect))
            return; // error
    }

    memmove(pos, data.ptr, data.length);
    if (mprotect(pos, page, oldProtect) != 0)
    {
        // error
    }
}
