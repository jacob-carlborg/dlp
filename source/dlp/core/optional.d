module dlp.core.optional;

import dlp.core.traits : isNullable;

private struct None {}

version (unittest)
{
    // Cannot put this inside the unittest block due to
    // https://issues.dlang.org/show_bug.cgi?id=19157
    private struct Foo
    {
        int a;
        Bar* b;

        int c(int a)
        {
            return a;
        }

        Bar d(int a)
        {
            return Bar(a);
        }
    }

    private struct Bar
    {
        int a;

        int foo(int a)
        {
            return a;
        }
    }
}

struct Optional(T)
{
    import std.traits : Unqual;

    // private alias OriginalType = U;
    // private alias T = Unqual!U;

    private Unqual!T value;

    static if (!isNullable!T)
        private bool present;

    this(T value)
    {
        opAssign(value);
    }

    this(None)
    {

    }

    void opAssign(T value)
    {
        this.value = value;

        static if (!isNullable!T)
            present = true;
    }

    void opAssign(None)
    {
        static if (isNullable!T)
            value = null;
        else
            present = false;
    }

    unittest
    {
        enum newVale = 4;
        Optional!int a = 3;
        a = newVale;
        assert(a.get == newVale);
    }

    unittest
    {
        Optional!int a = 3;
        a = none;
        assert(!a.isPresent);
    }

    bool isPresent() const
    {
        static if (isNullable!T)
            return value !is null;

        else
            return present;
    }

    unittest
    {
        Optional!int a = 3;
        assert(a.isPresent);

        Optional!(int*) b = null;
        assert(!b.isPresent);
    }

    inout(T) get() inout
    {
        assert(isPresent);
        return value;
    }

    unittest
    {
        Optional!int a = 3;
        assert(a.get == 3);
    }

    bool empty() const
    {
        return !isPresent;
    }

    unittest
    {
        Optional!int a = 3;
        assert(!a.empty);

        Optional!int b = none;
        assert(b.empty);
    }

    T front()
    {
        return get;
    }

    unittest
    {
        Optional!int a = 3;
        assert(a.get == 3);
    }

    void popFront()
    {
        static if (isNullable!T)
            value = null;
        else
            present = false;
    }

    unittest
    {
        Optional!int a = 3;
        a.popFront();
        assert(!a.isPresent);
    }

    size_t length()
    {
        return isPresent ? 1 : 0;
    }

    unittest
    {
        Optional!int a = 3;
        assert(a.length == 1);

        Optional!int b = none;
        assert(b.length == 0);
    }

    auto ref opDispatch(string name, Args...)(auto ref Args args)
    {
        import std.traits : PointerTarget, isPointer;
        import dlp.core.traits : hasField, TypeOfMember, getMember;

        static if (isPointer!T)
            alias StoredType = PointerTarget!T;
        else
            alias StoredType = T;

        static if (is(StoredType == class) || is(StoredType == struct))
        {
            static if (hasField!(StoredType, name))
            {
                alias FieldType = TypeOfMember!(StoredType, name);

                if (isPresent)
                    return optional(value.getMember!name);
                else
                    return none!FieldType;
            }
            else
            {
                alias ReturnType = typeof(__traits(getMember, value, name)(args));

                if (isPresent)
                    return optional(__traits(getMember, value, name)(args));
                else
                    return none!ReturnType;
            }
        }
        else
        {
            return optional(value.getMember!name);
        }

        assert(0);
    }

    unittest
    {
        assert(Optional!Foo(Foo(3)).a.get == 3);
        assert(Optional!Foo.init.a.empty);

        assert(Optional!Foo(Foo()).opDispatch!"c"(4).get == 4);
        assert(Optional!Foo.init.c(4).empty);

        assert(Optional!Foo(Foo(1, new Bar(5))).b.a.get == 5);
        assert(Optional!Foo(Foo(1)).b.a.empty);
    }
}

Optional!T optional(T)(T value)
{
    return Optional!T(value);
}

unittest
{
    assert(optional(3).isPresent);
}

unittest
{
    int i;
    assert(optional(&i).isPresent);
    assert(!optional!(int*)(null).isPresent);
}

unittest
{
    import std.algorithm : map;

    enum value = 3;
    assert(optional(value).map!(e => e).front == value);
}

Optional!T some(T)(T value)
in
{
    static if (isNullable!T)
        assert(value !is null);
}
do
{
    Optional!T o;
    o.value = value;

    static if (!isNullable!(T))
        o.present = true;

    return o;
}

unittest
{
    assert(some(3).isPresent);
}

unittest
{
    int a;
    int* b = &a;
    assert(some(b).isPresent);
}

None none() pure nothrow @nogc @safe
{
    return None();
}

Optional!T none(T)()
{
    return Optional!T.init;
}

unittest
{
    assert(!none!int.isPresent);
}

T or(Range, T)(Range range, lazy T alternativeValue)
{
    return range.empty ? alternativeValue : range.front;
}

unittest
{
    Optional!int a = 3;
    assert(a.or(4) == 3);

    Optional!int b = none;
    assert(b.or(4) == 4);
}
