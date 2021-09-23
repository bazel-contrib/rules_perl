"""Toolchains for Perl rules.
perl_toolchain creates a provider as described in PerlToolchainInfo in
providers.bzl. toolchains and perl_toolchains are declared in the build file
generated in perl_download in repo.bzl.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")

PerlRuntimeInfo = provider(
    doc = "Information about a Perl interpreter, related commands and libraries",
    fields = {
        "interpreter": "A label which points to the Perl interpreter",
        "xsubpp": "A label which points to the xsubpp command",
        "xs_headers": "The c library support code for xs modules",
        "runtime": "A list of lavels which points to runtime libraries",
        "perlopt": "A list of strings which should be passed to the interpreter",
    },
)

def _find_tool(ctx, name):
    cmd = None
    for f in ctx.files.runtime:
        if f.path.endswith("/bin/%s" % name) or f.path.endswith("/bin/%s.exe" % name):
            cmd = f
            break
    if not cmd:
        fail("could not locate perl tool `%s`" % name)

    return cmd

def _find_xs_headers(ctx):
    hdrs = [f for f in ctx.files.runtime
            if "CORE" in f.path and f.path.endswith(".h")]
    return depset(hdrs)

def _perl_toolchain_impl(ctx):
    # Find important files and paths.
    interpreter_cmd = _find_tool(ctx, "perl")
    xsubpp_cmd = _find_tool(ctx, "xsubpp")
    xs_headers = _find_xs_headers(ctx)

    return [
        platform_common.ToolchainInfo(
            perl_runtime = PerlRuntimeInfo(
                interpreter = interpreter_cmd,
                xsubpp = xsubpp_cmd,
                xs_headers = xs_headers,
                runtime = ctx.files.runtime,
                perlopt = ctx.attr.perlopt,
            ),
            make_variables = platform_common.TemplateVariableInfo({
                "PERL": interpreter_cmd.path,
            }),
        ),
    ]

perl_toolchain = rule(
    implementation = _perl_toolchain_impl,
    attrs = {
        "runtime": attr.label_list(
            mandatory = True,
            allow_files = True,
            cfg = "target",
        ),
        "perlopt": attr.string_list(
            default = [],
        ),
    },
    doc = "Gathers functions and file lists needed for a Perl toolchain",
)

def _current_perl_toolchain_impl(ctx):
    toolchain = ctx.toolchains[str(Label("//:toolchain_type"))]

    return [
        toolchain,
        toolchain.make_variables,
        DefaultInfo(
            runfiles = ctx.runfiles(
                files = toolchain.perl_runtime.runtime,
            ),
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
    toolchains = [
        str(Label("//:toolchain_type")),
    ],
)
