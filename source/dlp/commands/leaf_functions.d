module dlp.commands.leaf_functions;

import dmd.func : FuncDeclaration;
import dmd.dmodule : Module;
import dmd.frontend : deinitializeDMD;
import dmd.visitor : SemanticTimeTransitiveVisitor;

import dlp.core.set;
import dlp.commands.utility;

const struct Config
{
    mixin StandardConfig;
}

Set!FuncDeclaration leafFunctions(
    const string filename,
    const string content,
    const Config config = Config()
)
{
    scope (exit)
        deinitializeDMD();

    with (config)
        return runFullFrontend(
            filename, content, versionIdentifiers, importPaths, stringImportPaths
        ).leafFunctions();
}

private:

Set!FuncDeclaration leafFunctions(Module module_)
{
    extern (C++) static class Visitor : SemanticTimeTransitiveVisitor
    {
        import dmd.expression : CallExp;
        import dlp.core.optional : Optional, none;

        alias visit = typeof(super).visit;

        Optional!FuncDeclaration lastVisitedFuncDeclaration;
        private Set!FuncDeclaration leafFunctions;
        private Set!FuncDeclaration visitedFunctions;

        override void visit(CallExp e)
        {
            lastVisitedFuncDeclaration = none;
            super.visit(e);
        }

        override void visit(FuncDeclaration func)
        {
            import std.algorithm : each;

            if (func in visitedFunctions) return;

            visitedFunctions.put(func);
            lastVisitedFuncDeclaration = func;
            super.visit(func);
            lastVisitedFuncDeclaration.each!(f => leafFunctions.put(f));
        }
    }

    scope visitor = new Visitor;
    module_.accept(visitor);

    return visitor.leafFunctions;
}

version(unittest):

import dmd.globals : Loc;

import dlp.core.test;

string setup()
{
    return q{
        {
            import dmd.globals : global;
            global.params.showColumns = true;
        }

        scope (exit)
        {
            import dmd.frontend : deinitializeDMD;
            import dmd.globals : global;

            deinitializeDMD();
        }
    };
}

bool leafFunctionEqualsLoc(const string content, int line, int column)
{
    enum filename = "test.d";
    const expected = Loc(filename, line, column);

    const leafFunctions = leafFunctions(filename, content);

    if (leafFunctions.length == 0)
        return false;

    const actual = leafFunctions[].front.loc;

    return actual.equals(expected);
}

@test("leaf function") unittest
{
    mixin(setup);

    enum content = q{
        #line 10
        void foo() {}
    };

    assert(leafFunctionEqualsLoc(content, 10, 14));
}

@test("non leaf function") unittest
{
    mixin(setup);

    enum content = q{
        import std.stdio;
        void foo()
        {
            write();
        }
    };

    assert(leafFunctions("test.d", content)[].empty);
}

@test("circular calls - non leaf functions") unittest
{
    mixin(setup);

    enum content = q{
        void a()
        {
            b();
        }

        void b()
        {
            a();
        }
    };

    assert(leafFunctions("test.d", content)[].empty);
}

@test("leaf function inside template mixin") unittest
{
    mixin(setup);

    enum content = q{
        mixin template Foo()
        {
            #line 10
            void foo() {}
        }

        mixin Foo;
    };

    assert(leafFunctionEqualsLoc(content, 10, 18));
}

@test("multiple functions on the same line") unittest
{
    mixin(setup);

    enum content = q{
        #line 10
        void foo() { bar(); } void bar() {}
    };

    assert(leafFunctionEqualsLoc(content, 10, 36));
}

@test("function without body") unittest
{
    mixin(setup);

    enum content = q{
        #line 10
        void foo();
    };

    assert(leafFunctionEqualsLoc(content, 10, 14));
}

@test("with imports") unittest
{
    mixin(setup);

    enum content = q{
        import std.stdio;
        #line 10
        void foo() {}
    };

    assert(leafFunctions("test.d", content).length == 1);
}

@test("nested function call") unittest
{
    mixin(setup);

    enum content = q{
        import std.stdio;
        void foo()
        {
            if (true)
                write();
        }
    };

    assert(leafFunctions("test.d", content)[].empty);
}

@test("nested function") unittest
{
    mixin(setup);

    enum content = q{
        void foo()
        {
            #line 10
            void bar() {}
            bar();
        }
    };

    assert(leafFunctionEqualsLoc(content, 10, 18));
}

@test("method") unittest
{
    mixin(setup);

    enum content = q{
        class Foo
        {
            #line 10
            void foo() {}
        }
    };

    assert(leafFunctionEqualsLoc(content, 10, 18));
}

@test("property function call") unittest
{
    mixin(setup);

    enum content = q{
        #line 10
        void a()
        {
            b;
        }

        void b()
        {
            a;
        }
    };

    assert(leafFunctions("test.d", content)[].empty);
}
