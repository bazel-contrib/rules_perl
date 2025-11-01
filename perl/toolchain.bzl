"""Toolchains for Perl rules.
perl_toolchain creates a provider as described in PerlToolchainInfo in
providers.bzl. toolchains and perl_toolchains are declared in the build file
generated in perl_download in repo.bzl.
"""

PerlRuntimeInfo = provider(
    doc = "Information about a Perl interpreter, related commands and libraries",
    fields = {
        "interpreter": "File: A label which points to the Perl interpreter",
        "perlopt": "list[str]: A list of strings which should be passed to the interpreter",
        "runtime": "depset[File]: A list of labels which points to runtime libraries",
        "xs_headers": "depset[File]: The c library support code for xs modules",
        "xsubpp": "File: A label which points to the xsubpp command",
    },
)

def _is_tool(src, name):
    endings = (
        "/bin/%s" % name,
        "/bin/%s.exe" % name,
        "/bin/%s.bat" % name,
    )
    if src.path.endswith(endings):
        return True

    return False

def _is_xs_header(src):
    if "CORE" in src.path and src.path.endswith(".h"):
        return True

    return False

def _rlocationpath(file, workspace_name):
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]
    return "{}/{}".format(workspace_name, file.short_path)

def _perl_toolchain_impl(ctx):
    # Find important files and paths.
    interpreter_cmd = None
    xsubpp_cmd = None
    xs_headers = []
    for file in ctx.files.runtime:
        if interpreter_cmd == None and _is_tool(file, "perl"):
            interpreter_cmd = file
            continue

        if xsubpp_cmd == None and _is_tool(file, "xsubpp"):
            xsubpp_cmd = file
            continue

        if _is_xs_header(file):
            xs_headers.append(file)
            continue

    if interpreter_cmd == None:
        fail("Failed to find perl interpreter.")

    if xsubpp_cmd == None:
        fail("Failed to find perl xsubpp.")

    interpreter_cmd_path = interpreter_cmd.path
    if ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]):
        interpreter_cmd_path = interpreter_cmd.path.replace("/", "\\")

    return [
        platform_common.ToolchainInfo(
            name = ctx.label.name,
            perl_runtime = PerlRuntimeInfo(
                interpreter = interpreter_cmd,
                xsubpp = xsubpp_cmd,
                xs_headers = depset(xs_headers),
                runtime = depset(ctx.files.runtime),
                perlopt = ctx.attr.perlopt,
            ),
            make_variables = platform_common.TemplateVariableInfo({
                "PERL": interpreter_cmd_path,
                "PERL_RLOCATIONPATH": _rlocationpath(interpreter_cmd, ctx.workspace_name),
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
                [],
                transitive_files = toolchain.perl_runtime.runtime,
            ),
            files = toolchain.perl_runtime.runtime,
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
