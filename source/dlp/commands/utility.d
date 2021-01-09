module dlp.commands.utility;

import dmd.astcodegen : ASTCodegen;
import dmd.dmodule : Module;
import dmd.dsymbol : Dsymbol;
import dmd.globals : Global;
import dmd.root.outbuffer : OutBuffer;
import dmd.target : Target;

mixin template StandardConfig()
{
    import dmd.target : Target;
    import dlp.core.optional : Optional, none;

    string[] importPaths = [];
    string[] stringImportPaths = [];
    string[] versionIdentifiers = [];
    Optional!string configFilename = none;
    Target.Architecture architecture = Target.defaultArchitecture;
}

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

string fullyQualifiedName(Dsymbol symbol) pure nothrow
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

bool hasErrors(const ref Global global) nothrow @nogc
{
    return global.errors > 0;
}

Module runFullFrontend(Config, Ast = ASTCodegen)(
    const string filename,
    const string content,
    const ref Config config)
{

    return runParser!(Config, Ast)(filename, content, config)
        .runSemanticAnalyzer(config.stringImportPaths);
}

Module runParser(Config, Ast = ASTCodegen)(
    const string filename,
    const string content,
    const ref Config config)
{
    import std.algorithm : each;
    import std.range : chain;

    import dmd.frontend : addImport, ContractChecks, initDMD, findImportPaths,
        parseModule, parseImportPathsFromConfig;
    import dmd.globals : global;
    import dmd.target : is64bit;

    import dlp.core.optional : or;

    global.params.mscoff = config.architecture.is64bit;
    initDMD(null, config.versionIdentifiers, ContractChecks(), config.architecture);

    findImportPaths(config.configFilename.or(""))
        .chain(config.importPaths)
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
