module dlp.core.test;

version(unittest):

struct test
{
    string name;
}

private:

extern (C) void _d_print_throwable(Throwable t);

shared static this()
{
    import core.runtime : Runtime;

    Runtime.extendedModuleUnitTester = &unitTesterRunner;
}

/**
 * Unit test runner that print summary to stdout.
 *
 * PowerShell considers anything printed to stderr as an error. The
 * default unit test runner implemented by druntime will print a summary
 * to stderr. This will cause the CI pipeline on AppVeyor to fail.
 *
 * Since there's no API to change where the summary is printed, it's
 * necessary to reimplement the unit test runner. This implementation is copied
 * from druntime, with a few things removed that are not necessary.
 */
auto unitTesterRunner()
{
    import core.runtime : UnitTestResult;
    import core.stdc.stdio : printf;

    UnitTestResult results;

    foreach ( m; ModuleInfo )
    {
        if ( !m )
            continue;
        auto fp = m.unitTest;
        if ( !fp )
            continue;

        import core.exception;
        ++results.executed;
        try
        {
            fp();
            ++results.passed;
        }
        catch ( Throwable e )
        {
            printf("%.*s(%llu): [unittest] %.*s\n",
                cast(int) e.file.length, e.file.ptr, cast(ulong) e.line,
                cast(int) e.message.length, e.message.ptr);
            if ( typeid(e) == typeid(AssertError) )
            {
                // Crude heuristic to figure whether the assertion originates in
                // the unittested module. TODO: improve.
                auto moduleName = m.name;
                if (moduleName.length && e.file.length > moduleName.length
                    && e.file[0 .. moduleName.length] == moduleName)
                {
                    // Exception originates in the same module, don't print
                    // the stack trace.
                    // TODO: omit stack trace only if assert was thrown
                    // directly by the unittest.
                    continue;
                }
            }
            // TODO: perhaps indent all of this stuff.
            _d_print_throwable(e);
        }
    }

    if (results.passed == results.executed)
        printf("%d modules passed unittests\n", cast(int) results.passed);
    else
        results.summarize = true;

    return results;
}
