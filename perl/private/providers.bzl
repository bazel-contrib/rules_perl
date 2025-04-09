"""Perl providers"""

PerlInfo = provider(
    doc = "A provider containing components of a `perl_library`",
    fields = {
        "includes": "list[str]: Include paths to add to `PERL5LIB`.",
        "transitive_perl_sources": "list[File]: Transitive perl source dependencies.",
    },
)
