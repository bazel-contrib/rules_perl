"""Toolchains for Perl rules.
perl_toolchain creates a provider as described in PerlToolchainInfo in
providers.bzl. toolchains and perl_toolchains are declared in the build file
generated in perl_download in repo.bzl.
"""

PerlRuntimeInfo = provider(
    doc = "Information about a Perl interpreter, related commands and libraries",
    fields = {
        "interpreter": "A label which points to the Perl interpreter",
        "perlopt": "A list of strings which should be passed to the interpreter",
        "runtime": "A list of labels which points to runtime libraries",
        "xs_headers": "The c library support code for xs modules",
        "xsubpp": "A label which points to the xsubpp command",
    },
)

def _find_tool(ctx, name):
    cmd = None
    for f in ctx.files.runtime:
        if f.path.endswith("/bin/%s" % name) or f.path.endswith("/bin/%s.exe" % name) or f.path.endswith("/bin/%s.bat" % name):
            cmd = f
            break
    if not cmd:
        fail("could not locate perl tool `%s`" % name)

    return cmd

def _find_xs_headers(ctx):
    hdrs = [
        f
        for f in ctx.files.runtime
        if "CORE" in f.path and f.path.endswith(".h")
    ]
    return depset(hdrs)

def _perl_toolchain_impl(ctx):
    # Find important files and paths.
    interpreter_cmd = _find_tool(ctx, "perl")
    xsubpp_cmd = _find_tool(ctx, "xsubpp")
    xs_headers = _find_xs_headers(ctx)

    interpreter_cmd_path = interpreter_cmd.path
    if ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]):
        interpreter_cmd_path = interpreter_cmd.path.replace("/", "\\")

    return [
        platform_common.ToolchainInfo(
            name = ctx.label.name,
            perl_runtime = PerlRuntimeInfo(
                interpreter = interpreter_cmd,
                xsubpp = xsubpp_cmd,
                xs_headers = xs_headers,
                runtime = ctx.files.runtime,
                perlopt = ctx.attr.perlopt,
            ),
            make_variables = platform_common.TemplateVariableInfo({
                "PERL": interpreter_cmd_path,
            }),
        ),
    ]

perl_toolchain = rule(
    implementation = _perl_toolchain_impl,
    attrs = {
        "perlopt": attr.string_list(
            default = [],
        ),
        "runtime": attr.label_list(
            mandatory = True,
            allow_files = True,
            cfg = "target",
        ),
        "_windows_constraint": attr.label(default = "@platforms//os:windows"),
    },
    doc = "Gathers functions and file lists needed for a Perl toolchain",
)

def _current_perl_toolchain_impl(ctx):
    toolchain = ctx.toolchains["@rules_perl//perl:toolchain_type"]

    return [
        toolchain,
        toolchain.make_variables,
        DefaultInfo(
            runfiles = ctx.runfiles(
                files = toolchain.perl_runtime.runtime,
            ),
            files = depset(toolchain.perl_runtime.runtime),
        ),
    ]

# This rule exists so that the current perl toolchain can be used in the `toolchains` attribute of
# other rules, such as genrule. It allows exposing a perl_toolchain after toolchain resolution has
# happened, to a rule which expects a concrete implementation of a toolchain, rather than a
# toochain_type which could be resolved to that toolchain.
#
# See https://github.com/bazelbuild/bazel/issues/14009#issuecomment-921960766
current_perl_toolchain = rule(
    implementation = _current_perl_toolchain_impl,
    toolchains = ["@rules_perl//perl:toolchain_type"],
)
