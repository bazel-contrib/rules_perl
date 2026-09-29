"""Checks which perl toolchain resolves under a value of --//perl/settings:xs."""

def _xs_transition_impl(_settings, attr):
    return {"//perl/settings:xs": attr.xs}

_xs_transition = transition(
    implementation = _xs_transition_impl,
    inputs = [],
    outputs = ["//perl/settings:xs"],
)

def _resolved_perl_impl(ctx):
    runtime = ctx.attr.toolchain[0][platform_common.ToolchainInfo].perl_runtime
    repo = runtime.interpreter.owner.repo_name
    if ctx.attr.expect not in repo:
        fail("with --//perl/settings:xs={}, expected a perl from a repository named *{}*, resolved @{}".format(
            ctx.attr.xs,
            ctx.attr.expect,
            repo,
        ))
    return [DefaultInfo(files = depset([runtime.interpreter]))]

resolved_perl = rule(
    doc = """Fails at analysis unless the perl toolchain that resolves with
    `--//perl/settings:xs` set to `xs` comes from a repository whose name
    contains `expect`.""",
    implementation = _resolved_perl_impl,
    attrs = {
        "expect": attr.string(
            doc = "A substring of the name of the repository the resolved perl must come from.",
            mandatory = True,
        ),
        "toolchain": attr.label(
            doc = "The target exposing the resolved perl toolchain, built with `xs` applied.",
            cfg = _xs_transition,
            default = Label("//perl:current_toolchain"),
        ),
        "xs": attr.bool(
            doc = "The value of `--//perl/settings:xs` to resolve under.",
            mandatory = True,
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
