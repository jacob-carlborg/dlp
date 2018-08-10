module dlp.visitors.utility;

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

    return buf.peekSlice.idup;
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
