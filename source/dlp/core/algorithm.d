module dlp.core.algorithm;

template flatMap(func...)
if (func.length >= 1)
{
    import std.range : isInputRange;
    import std.traits : Unqual;

    auto flatMap(Range)(Range range) if (isInputRange!(Unqual!Range))
    {
        import std.algorithm : map, joiner;

        return range.map!func.joiner;
    }
}

///
unittest
{
    import std.algorithm : equal;

    [1, 2, 3, 4]
        .flatMap!(e => [e, -e])
        .equal([1, -1, 2, -2, 3, -3, 4, -4]);
}
