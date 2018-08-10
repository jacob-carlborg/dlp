module dlp.core.traits;

import std.traits : isAssociativeArray, isDynamicArray, isPointer;

/// Evaluates to `true` if the given type can hold `null`.
template isNullable(T)
{
    enum isNullable = is(T == class) || is(T == interface) ||
        is(T == function) || is(T == delegate) || isAssociativeArray!T ||
        isDynamicArray!T || isPointer!T;
}

///
unittest
{
    assert(isNullable!Object);
    assert(isNullable!(Object.Monitor));
    assert(isNullable!(void function()));
    assert(isNullable!(void delegate()));
    assert(isNullable!(int*));
    assert(!isNullable!int);
}

// /**
//  * Returns `true` if `T` has a field with the given name $(D_PARAM field).
//  *
//  * Params:
//  *  T = the type of the class/struct
//  *  field = the name of the field
//  *
//  * Returns: `true` if `T` has a field with the given name $(D_PARAM field)
//  */
// bool hasField(T, string field)()
// {
//     static foreach (i; 0 .. T.tupleof.length)
//     {
//         static if (nameOfFieldAt!(T, i) == field)
//             return true;
//         else
//             return false;
//     }
// }

template hasField (T, string field)
{
    enum hasField = hasFieldImpl!(T, field, 0);
}

private template hasFieldImpl (T, string field, size_t i)
{
    static if (T.tupleof.length == i)
        enum hasFieldImpl = false;

    else static if (nameOfFieldAt!(T, i) == field)
        enum hasFieldImpl = true;

    else
        enum hasFieldImpl = hasFieldImpl!(T, field, i + 1);
}

///
unittest
{
    static struct Foo
    {
        int bar;
    }

    assert(hasField!(Foo, "bar"));
    assert(!hasField!(Foo, "foo"));
}

/**
 * Evaluates to a string containing the name of the field at given position in the given type.
 *
 * Params:
 *  T = the type of the class/struct
 *  position = the position of the field in the tupleof array
 */
template nameOfFieldAt (T, size_t position)
{
    import std.format : format;

    enum errorMessage = `The given position "%s" is greater than the number ` ~
        `of fields (%s) in the type "%s"`;

    static assert (position < T.tupleof.length, format(errorMessage, position,
        T.tupleof.length, T.stringof));

    enum nameOfFieldAt = __traits(identifier, T.tupleof[position]);
}

///
unittest
{
    static struct Foo
    {
        int foo;
        int bar;
    }

    assert(nameOfFieldAt!(Foo, 1) == "bar");
}

/**
 * Returns `true` if `T` has a member with the given name $(D_PARAM member).
 *
 * Params:
 *  T = the type of the class/struct
 *  member = the name of the member
 *
 * Returns: `true` if `T` has a member with the given name $(D_PARAM member)
 */
bool hasMember(T, string member)()
{
    return __traits(hasMember, T, member);
}

///
unittest
{
    static struct Foo
    {
        int bar;
    }

    assert(hasMember!(Foo, "bar"));
    assert(!hasMember!(Foo, "foo"));
}

/**
 * Evaluates to the type of the member with the given name
 *
 * Params:
 *  T = the type of the class/struct
 *  member = the name of the member
 */
template TypeOfMember (T, string member)
{
    import std.format : format;

    enum errorMessage = `The given member "%s" does not exist in the type "%s"`;

    static if (!hasMember!(T, member))
        static assert(false, format(errorMessage, member, T.stringof));

    else
        alias TypeOfMember = typeof(__traits(getMember, T, member));
}

///
unittest
{
    static struct Foo
    {
        int foo;
    }

    assert(is(TypeOfMember!(Foo, "foo") == int));
    assert(!__traits(compiles, { alias T = TypeOfMember!(Foo, "bar"); }));
}

auto ref getMember(string member, T)(auto ref T value)
{
    enum errorMessage = `The given member "%s" does not exist in the type "%s"`;

    static if (!hasMember!(T, member))
        static assert(false, format(errorMessage, member, T.stringof));
    else
        return __traits(getMember, value, member);
}

unittest
{
    static struct Foo
    {
        int foo;
    }

    assert(Foo(3).getMember!"foo" == 3);
}
