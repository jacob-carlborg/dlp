module dlp.commands.utility;

import dmd.astcodegen : ASTCodegen;
import dmd.dmodule : Module;
import dmd.dsymbol : Dsymbol;
import dmd.globals : Global;
import dmd.root.outbuffer : OutBuffer;

class DiagnosticsException : Exception
{
    import dmd.frontend : Diagnostics;

    Diagnostics diagnostics;

    @nogc @safe pure nothrow this(Diagnostics diagnostics,
        string file = __FILE__, size_t line = __LINE__,
        Throwable nextInChain = null)
    {
        this.diagnostics = diagnostics;
        super(null, file, line, nextInChain);
    }
}

string fullyQualifiedName(Dsymbol symbol)
{
    OutBuffer buf;
    buf.writestring(symbol.ident.toString());

    for (auto package_ = symbol.parent; package_ !is null; package_ = package_.parent)
    {
        buf.prependstring(".");
        buf.prependstring(package_.ident.toChars());
    }

    return buf.extractSlice();
}

void handleDiagnosticErrors()
{
    import dmd.frontend : Diagnostics;
    import dmd.globals : global;

    if (!global.hasErrors)
        return;

    Diagnostics diagnostics = {
        errors: global.errors,
        warnings: global.warnings
    };

    throw new DiagnosticsException(diagnostics);
}

bool hasErrors(const ref Global global)
{
    return global.errors > 0;
}

Module runFullFrontend(Ast = ASTCodegen)(
    const string filename,
    const string content,
    const string[] versionIdentifiers,
    const string[] importPaths,
    const string[] stringImportPaths)
{

    return runParser!Ast(filename, content, versionIdentifiers, importPaths)
        .runSemanticAnalyzer(stringImportPaths);
}

Module runParser(Ast = ASTCodegen)(
    const string filename,
    const string content,
    const string[] versionIdentifiers,
    const string[] importPaths)
{
    import std.algorithm : each;
    import std.range : chain;

    import dmd.frontend : addImport, initDMD, findImportPaths,
        parseModule, parseImportPathsFromConfig;
    import dmd.globals : global;

    global.params.mscoff = global.params.is64bit;
    initDMD(null, versionIdentifiers);

    findImportPaths
        .chain(importPaths)
        .each!addImport;

    auto t = parseModule!Ast(filename, content);

    if (t.diagnostics.hasErrors)
        throw new DiagnosticsException(t.diagnostics);

    return t.module_;
}

Module runSemanticAnalyzer(Module module_, const string[] stringImportPaths)
{
    import std.algorithm : each;

    import dmd.frontend : addStringImport, fullSemantic;

    stringImportPaths.each!addStringImport;

    fullSemantic(module_);
    handleDiagnosticErrors();

    return module_;
}
