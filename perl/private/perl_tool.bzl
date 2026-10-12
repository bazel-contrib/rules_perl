"""A perl script usable as a build tool without a shell launcher."""

PerlToolInfo = provider(
    doc = "A perl script and the interpreter to run it with, for use in build actions.",
    fields = {
        "interpreter": "File: The perl interpreter. Use as an action's `executable`.",
        "main": "File: The script to pass as the interpreter's first argument.",
        "tools": "depset[File]: Files the action needs, including the interpreter's runtime.",
    },
)

def _perl_tool_impl(ctx):
    toolchain = ctx.toolchains["@rules_perl//perl:toolchain_type"].perl_runtime

    return [
        PerlToolInfo(
            interpreter = toolchain.interpreter,
            main = ctx.file.main,
            tools = depset([ctx.file.main], transitive = [toolchain.runtime]),
        ),
        DefaultInfo(files = depset([ctx.file.main])),
    ]

perl_tool = rule(
    doc = """A perl script run directly by the interpreter in build actions.

    Unlike `perl_binary`, there is no launcher script, so actions do not depend on a
    shell or other host tools. Depend on it with `cfg = "exec"` so the interpreter is
    resolved for the execution platform. The script may only use core modules.
    """,
    implementation = _perl_tool_impl,
    attrs = {
        "main": attr.label(
            doc = "The perl script to run.",
            allow_single_file = [".pl"],
            mandatory = True,
        ),
    },
    toolchains = ["@rules_perl//perl:toolchain_type"],
)
