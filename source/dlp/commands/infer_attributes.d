module dlp.commands.infer_attributes;

import std.stdio;
import std.string;

import dmd.declaration : Declaration;
import dmd.dmodule : Module;
import dmd.dscope : Scope;
import dmd.frontend : deinitializeDMD;
import dmd.func;
import dmd.visitor : SemanticTimeTransitiveVisitor, Visitor;

import dlp.commands.utility;
import dlp.core.optional;
import dlp.core.redirect;
import dlp.core.set;

Optional!string inputFilename;

struct Attributes
{
    bool isNogc;
    bool isNothrow;
    bool isPure;
    bool isSafe;

    /// Returns: `true` if any attributes were inferred
    bool inferred() const pure nothrow @nogc @safe
    {
        return this != Attributes.init;
    }

    string toString() const pure
    {
        import std.array : join;
        import std.format : format;
        import std.range : empty;

        if (!inferred)
            return "";

        string[] attributes;

        if (isPure)
            attributes ~= "pure";

        if (isNothrow)
            attributes ~= "nothrow";

        if (isNogc)
            attributes ~= "@nogc";

        if (isSafe)
            attributes ~= "@safe";

        return attributes.join(" ");
    }
}

const(Attributes[FuncDeclaration]) inferAttributes(
    const string filename,
    const string content,
    const string[] versionIdentifiers = [],
    const string[] importPaths = [],
    const string[] stringImportPaths = []
)
{
    inputFilename = filename;
    auto context = redirect!(FuncDeclaration.canInferAttributes,
        RedirectedFuncDeclaration.canInferAttributes);

    scope (exit)
    {
        context.restore();
        inputFilename = none;
        deinitializeDMD();
    }

    return runParser(filename, content, versionIdentifiers, importPaths)
        .inferAttributes(stringImportPaths);
}

private:

extern (C++) class RedirectedFuncDeclaration
{
    final bool canInferAttributes(Scope* sc)
    {
        auto self = cast(FuncDeclaration) this;

        if (!self.fbody)
            return false;

        assert(inputFilename.isPresent);
        const isFromInputFile = self.loc.filename.fromStringz == inputFilename.get;

        return canInferAttributesOriginal(self, sc) || isFromInputFile;
    }

    final bool canInferAttributesOriginal(FuncDeclaration self, Scope* sc)
    {
        import dmd.declaration : STC;

        with (self)
        {
            if (!fbody)
                return false;

            if (isVirtualMethod())
                return false;               // since they may be overridden

            if (sc.func &&
                /********** this is for backwards compatibility for the moment ********/
                (!isMember() || sc.func.isSafeBypassingInference() && !isInstantiated()))
                return true;

            if (isFuncLiteralDeclaration() ||               // externs are not possible with literals
                (storage_class & STC.inference) ||           // do attribute inference
                (inferRetType && !isCtorDeclaration()))
                return true;

            if (isInstantiated())
            {
                auto ti = parent.isTemplateInstance();
                if (ti is null || ti.isTemplateMixin() || ti.tempdecl.ident == ident)
                    return true;
            }

            return false;
        }
    }
}

const(Attributes[FuncDeclaration]) inferAttributes(
    Module module_,
    const string[] stringImportPaths
)
{
    import std.algorithm : each, map;
    import std.meta : AliasSeq;

    import dmd.attrib : StorageClassDeclaration;
    import dmd.declaration : STC;
    import dmd.globals : Loc, StorageClass;
    import dmd.mtype : PURE;

    alias DeclaredAttributes = Attributes[void*];

    static const(Attributes) extractAttributes(
        FuncDeclaration func, StorageClassDeclaration[] storageClassDeclarations
    )
    {
        static Attributes extractFromStorageClass(StorageClass storageClass)
        {
            Attributes attributes = {
                isNogc: (storageClass & STC.nogc) != 0,
                isNothrow: (storageClass & STC.nothrow_) != 0,
                isPure: (storageClass & STC.pure_) != 0,
                isSafe: (storageClass & STC.safe) != 0,
            };

            return attributes;
        }

        static const(StorageClass) extractStorageClass(
            StorageClassDeclaration[] storageClassDeclarations
        )
        {
            import std.algorithm : fold;

            if (storageClassDeclarations.empty)
                return StorageClass.init;

            return storageClassDeclarations
                .map!(e => e.stc)
                .fold!((acc, stc) => acc |= stc)(StorageClass.init);
        }

        const storageClass = extractStorageClass(storageClassDeclarations);
        const storageClassAttributes = extractFromStorageClass(storageClass);

        Attributes attachedAttributes;

        if (func.type) with(attachedAttributes)
        {
            isNogc = func.isNogc;
            isNothrow = func.type.toTypeFunction.isnothrow;
            isPure = func.isPure != PURE.impure;
            isSafe = func.isSafe;
        }

        else
            attachedAttributes = extractFromStorageClass(func.storage_class);

        Attributes newAttributes;

        foreach (i, ref field; newAttributes.tupleof)
            field = attachedAttributes.tupleof[i]
                || storageClassAttributes.tupleof[i];

        return newAttributes;
    }

    extern (C++) static class ParseTimeVisitor : SemanticTimeTransitiveVisitor
    {
        alias visit = typeof(super).visit;

        DeclaredAttributes declaredAttributes;
        StorageClassDeclaration[] storageClassDeclarations;

        override void visit(FuncDeclaration func)
        {
            declaredAttributes[cast(void*) func] =
                extractAttributes(func, storageClassDeclarations);
        }

        override void visit(StorageClassDeclaration scd)
        {
            import std.range : popBack;

            storageClassDeclarations ~= scd;

            scope (exit)
                storageClassDeclarations.popBack();

            super.visit(scd);
        }

        private alias functionSubclasses = AliasSeq!(
            StaticCtorDeclaration,
            StaticDtorDeclaration,
            PostBlitDeclaration,
            DtorDeclaration
        );

        static foreach (subclass; functionSubclasses)
        {
            // not sure why this is needed
            override void visit(subclass func)
            {
                visit(cast(FuncDeclaration) func);
            }
        }
    }

    extern (C++) static class Visitor : SemanticTimeTransitiveVisitor
    {
        alias visit = typeof(super).visit;

        Attributes[void*] inferredAttributes;
        private const DeclaredAttributes declaredAttributes;

        extern (D) this(DeclaredAttributes declaredAttributes)
        {
            this.declaredAttributes = declaredAttributes;
        }

        override void visit(FuncDeclaration func)
        {
            if (cast(void*) func !in this.declaredAttributes)
                return;

            if (func.type)
                assert(func.isPure != PURE.fwdref);

            const declaredAttributes = this.declaredAttributes[cast(void*) func];
            const inferredAttributes = extractAttributes(func, []);

            Attributes normalizedAttributes;

            foreach (i, ref field; normalizedAttributes.tupleof)
                field = !declaredAttributes.tupleof[i]
                    && inferredAttributes.tupleof[i];

            if (normalizedAttributes.inferred)
                this.inferredAttributes[cast(void*) func] = normalizedAttributes;
        }

        private alias functionSubclasses = AliasSeq!(
            StaticCtorDeclaration,
            StaticDtorDeclaration,
            PostBlitDeclaration,
            DtorDeclaration
        );

        static foreach (subclass; functionSubclasses)
        {
            // not sure why this is needed
            override void visit(subclass func)
            {
                visit(cast(FuncDeclaration) func);
            }
        }
    }

    scope parseTimeVisitor = new ParseTimeVisitor;
    module_.accept(parseTimeVisitor);

    module_.runSemanticAnalyzer(stringImportPaths);

    scope visitor = new Visitor(parseTimeVisitor.declaredAttributes);
    module_.accept(visitor);

    if (visitor.inferredAttributes.length == 0)
        return null;
    else
        return cast(Attributes[FuncDeclaration]) visitor.inferredAttributes;
}

version (unittest):

import core.stdc.stdarg;

import dmd.console : Color;
import dmd.errors;
import dmd.globals : Loc;

import dlp.core.test;

enum setup = q{
    scope (exit)
    {
        import dmd.frontend : deinitializeDMD;
        deinitializeDMD();
    }
};

enum suppressDiagnostics = q{
    auto context = redirect!(
        __traits(getMember, dmd.errors, "verrorPrint"),
        suppressedVerrorPrint
    );
    scope (exit)
        context.restore();
};

void suppressedVerrorPrint(const ref Loc, Color, const(char)*, const(char)*,
    va_list, const(char)* = null, const(char)* = null) nothrow
{
    // noop
}

@test("base case, empty function") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: true,
        isPure: true,
        isSafe: true
    };

    enum content = q{
        void foo() {}
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("using the GC") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: false,
        isNothrow: true,
        isPure: true,
        isSafe: true
    };

    enum content = q{
        void foo()
        {
            new Object;
        }
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("throwing exception") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: false,
        isPure: true,
        isSafe: true
    };

    enum content = q{
        void foo()
        {
            Exception e;
            throw e;
        }
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("accessing TLS variable") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: true,
        isPure: false,
        isSafe: true
    };

    enum content = q{
        int a;
        void foo()
        {
            auto b = a;
        }
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("accessing `.ptr` of array") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: true,
        isPure: true,
        isSafe: false
    };

    enum content = q{
        void foo()
        {
            int[] a;
            auto b = a.ptr;
        }
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("function without body") unittest
{
    mixin(setup);

    enum content = q{
        void foo();
    };

    assert(inferAttributes("test.d", content).length == 0);
}

@test("template") unittest
{
    mixin(setup);

    enum content = q{
        void foo()() {}
    };

    assert(inferAttributes("test.d", content).length == 0);
}

@test("lambda") unittest
{
    mixin(setup);

    enum content = q{
        alias foo = a => a + 2;
    };

    assert(inferAttributes("test.d", content).length == 0);
}

@test("nested function") unittest
{
    mixin(setup);

    enum content = q{
        void foo()
        {
            void bar() {}
        }
    };

    assert(inferAttributes("test.d", content).length == 1);
}

@test("lambda") unittest
{
    mixin(setup);

    enum content = q{
        alias foo = a => a + 2;
    };

    assert(inferAttributes("test.d", content).length == 0);
}

@test("declared as @nogc") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: false,
        isNothrow: true,
        isPure: true,
        isSafe: true
    };

    enum content = q{
        @nogc void foo() {}
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("declared as nothrow") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: false,
        isPure: true,
        isSafe: true
    };

    enum content = q{
        nothrow void foo() {}
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("declared as pure") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: true,
        isPure: false,
        isSafe: true
    };

    enum content = q{
        pure void foo() {}
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("declared as @safe") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: true,
        isPure: true,
        isSafe: false
    };

    enum content = q{
        @safe void foo() {}
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("nothing inferred") unittest
{
    mixin(setup);

    enum content = q{
        pure nothrow @nogc @safe void foo() {}
    };

    assert(inferAttributes("test.d", content).length == 0);
}

@test("declared as nothrow:") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: false,
        isPure: true,
        isSafe: true
    };

    enum content = q{
        nothrow:
        void foo() {}
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("declared as nothrow{}") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: false,
        isPure: true,
        isSafe: true
    };

    enum content = q{
        nothrow
        {
            void foo() {}
        }
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("declared as pure and nothrow:") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: false,
        isPure: false,
        isSafe: true
    };

    enum content = q{
        nothrow:
        pure void foo() {}
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("multiple storage class declarations") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: false,
        isNothrow: false,
        isPure: true,
        isSafe: false
    };

    enum content = q{
        nothrow:
        @nogc:
        @safe:

        void foo() {}
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("method") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: true,
        isPure: true,
        isSafe: true
    };

    enum content = q{
        struct Foo
        {
            int a;
            void bar()
            {
                a = 3;
            }
        }
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("postblit") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: true,
        isPure: true,
        isSafe: true
    };

    enum content = q{
        struct Foo
        {
            this(this)
            {

            }
        }
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("disabled postblit in template struct") unittest
{
    mixin(setup);

    enum content = q{
        struct Array()
        {
            @disable this(this);
        }
    };

    assert(inferAttributes("test.d", content).length == 0);
}

@test("constructor") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: true,
        isPure: true,
        isSafe: true
    };

    enum content = q{
        class Foo
        {
            this() {}
        }
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("destructor") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: true,
        isPure: true,
        isSafe: true
    };

    enum content = q{
        struct Foo
        {
            ~this() {}
        }
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("static constructor") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: true,
        isPure: true,
        isSafe: true
    };

    enum content = q{
        static this() {}
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("static destructor") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: true,
        isPure: true,
        isSafe: true
    };

    enum content = q{
        static ~this() {}
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("shared static constructor") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: true,
        isPure: true,
        isSafe: true
    };

    enum content = q{
        shared static this() {}
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

@test("shared static destructor") unittest
{
    mixin(setup);

    enum Attributes expected = {
        isNogc: true,
        isNothrow: true,
        isPure: true,
        isSafe: true
    };

    enum content = q{
        shared static ~this() {}
    };

    assert(inferAttributesEqualsAttributes(content, expected));
}

bool inferAttributesEqualsAttributes(
    const string content, const Attributes attributes
)
{
    import std.algorithm : find;

    auto inferredAttributes = inferAttributes("test.d", content);
    assert(inferredAttributes.length > 0);

    return inferredAttributes.byValue.front == attributes;
}
