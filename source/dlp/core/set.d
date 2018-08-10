module dlp.core.set;

struct Set(T)
{
    private alias Value = void[0];
    private alias Key = KeyType!T;

    private alias ByKeyRange = typeof(
        delegate() const { return storage.byKey(); }()
    );

    Value[Key] storage;

    this(const T[] values ...)
    {
        put(values);
    }

    ///
    unittest
    {
        auto set = Set!int(1, 2, 3, 4);
    }

    this(const Set set)
    {
        put(set);
    }

    ///
    unittest
    {
        auto a = Set!int(1, 2, 3, 4);
        auto b = Set!int(a);

        assert(a == b);
    }

    void put(const T value) pure nothrow
    {
        storage[cast(Key) value] = Value.init;
    }

    ///
    unittest
    {
        Set!int set;
        set.put(3);

        assert(set.length == 1);
    }

    void put(const T[] values ...) pure nothrow
    {
        foreach (v; values)
            put(v);
    }

    ///
    unittest
    {
        Set!int set;
        set.put(1, 2, 3, 4);

        assert(set.length == 4);
    }

    void put(const Set set) pure nothrow
    {
        foreach (key; set[])
            put(key);
    }

    ///
    unittest
    {
        Set!int a;
        a.put(1);
        a.put(2);

        Set!int b;
        b.put(a);

        assert(b == a);
    }

    bool opBinaryRight(string op)(const T rhs)
        if (op == "in")
    {
        return (cast(Key) rhs in storage) !is null;
    }

    ///
    unittest
    {
        auto set = Set!int(1, 2);
        assert(2 in set);

        auto o = new Object;
        auto s = Set!Object(o);
        s.put(new Object);

        assert(o in s);
    }

    auto opSlice() const
    {
        return ByKeyRangeWrapper(storage.byKey);
    }

    ///
    unittest
    {
        import std.algorithm : map, canFind;

        auto set = Set!int(1, 2);
        auto range = set[].map!(e => e);

        // cannot compare "range" with another range since the order of a set is
        // not guaranteed.
        assert(range.canFind(1));
        assert(range.canFind(2));
    }

    size_t length() const
    {
        return storage.length;
    }

    ///
    unittest
    {
        auto set = Set!int(1, 2);
        assert(set.length == 2);
    }

    private static struct ByKeyRangeWrapper
    {
        private ByKeyRange range;

        T front()
        {
            return cast(T) range.front();
        }

        void popFront()
        {
            range.popFront();
        }

        bool empty()
        {
            return range.empty();
        }
    }
}

private template KeyType(T)
{
    static if (is(T == class) || is(T == interface))
    {
        static if (__traits(getLinkage, T) == "D" )
            alias KeyType = T;
        else
            alias KeyType = void*;
    }
    else
        alias KeyType = T;
}
