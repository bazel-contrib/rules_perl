"""Perl rules for Bazel"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load(":providers.bzl", "PerlInfo")

_PERL_FILE_TYPES = [".pl", ".pm", ".t", ".so", ".ix", ".al", ""]

_COMMON_PERL_ATTRS = {
    "data": attr.label_list(
        doc = "Files needed by this rule at runtime. May list file or rule targets. Generally allows any target.",
        allow_files = True,
    ),
    "deps": attr.label_list(
        doc = "Other perl targets to link to the current target.",
        allow_files = False,
        providers = [PerlInfo],
    ),
    "srcs": attr.label_list(
        doc = "The list of source files that are processed to create the target.",
        allow_files = _PERL_FILE_TYPES,
    ),
}

_LIBRARY_PERL_ATTRS = _COMMON_PERL_ATTRS | {
    "includes": attr.string_list(
        doc = "List of include dirs to be added to the Perl include path (`PERL5LIB`).",
        default = [".", "lib"],
    ),
}

_EXECUTABLE_PERL_ATTRS = _COMMON_PERL_ATTRS | {
    "env": attr.string_dict(
        doc = "Dictionary of strings; values are subject to `$(location)` and \"Make variable\" substitution.",
    ),
    "main": attr.label(
        doc = "The name of the source file that is the main entry point of the application.",
        allow_single_file = _PERL_FILE_TYPES,
    ),
    "_bash_runfiles": attr.label(
        cfg = "target",
        default = Label("@bazel_tools//tools/bash/runfiles"),
    ),
    "_entrypoint": attr.label(
        doc = "The executable entrypoint.",
        allow_single_file = True,
        default = Label("//perl/private:entrypoint.pl"),
    ),
    "_windows_constraint": attr.label(
        default = Label("@platforms//os:windows"),
    ),
    "_wrapper_template": attr.label(
        allow_single_file = True,
        default = Label("//perl/private:binary_wrapper.tpl"),
    ),
}

def _transitive_srcs(deps):
    return struct(
        srcs = [
            d[PerlInfo].transitive_perl_sources
            for d in deps
            if PerlInfo in d
        ],
        files = [
            d[DefaultInfo].default_runfiles.files
            for d in deps
        ],
    )

def _transitive_deps(ctx, extra_files = [], extra_deps = []):
    """Calculates transitive sets of args.

    Calculates the transitive sets for perl sources, data runfiles,
    include flags and runtime flags from the srcs, data and deps attributes
    in the context.

    Also adds extra_deps to the roots of the traversal.

    Args:
        ctx: a ctx object for a perl_library or a perl_binary rule.
        extra_files: a list of File objects to be added to the default_files
        extra_deps: a list of Target objects.
    """
    deps = _transitive_srcs(ctx.attr.deps + extra_deps)
    files = ctx.runfiles(
        files = extra_files + ctx.files.srcs + ctx.files.data,
        transitive_files = depset(transitive = deps.files),
        collect_default = True,
    )
    if hasattr(ctx.attr, "_bash_runfiles"):
        files = files.merge(ctx.attr._bash_runfiles.default_runfiles)
    return struct(
        srcs = depset(
            direct = ctx.files.srcs,
            transitive = deps.srcs,
        ),
        files = files,
    )

def _include_paths(ctx, includes, transitive_includes):
    """Determine the include paths from a target's `includes` attribute.

    Args:
        ctx (ctx): The rule's context object.
        includes (list): A list of include paths.
        transitive_includes (depset): Resolved includes form transitive dependencies.

    Returns:
        depset: A set of the resolved include paths.
    """
    workspace_name = ctx.label.workspace_name
    if not workspace_name:
        workspace_name = ctx.workspace_name

    include_root = "{}/{}".format(workspace_name, ctx.label.package).rstrip("/")

    result = [workspace_name]
    for include_str in includes:
        include_str = ctx.expand_make_variables("includes", include_str, {})
        if include_str.startswith("/"):
            continue

        # To prevent "escaping" out of the runfiles tree, we normalize
        # the path and ensure it doesn't have up-level references.
        include_path = paths.normalize("{}/{}".format(include_root, include_str))
        if include_path.startswith("../") or include_path == "..":
            fail("Path '{}' references a path above the execution root".format(
                include_str,
            ))
        result.append(include_path)

    return depset(result, transitive = [transitive_includes])

def _perl_library_implementation(ctx):
    transitive_sources = _transitive_deps(ctx)
    transitive_includes = depset(transitive = [dep[PerlInfo].includes for dep in ctx.attr.deps])
    return [
        DefaultInfo(
            runfiles = transitive_sources.files,
        ),
        PerlInfo(
            transitive_perl_sources = transitive_sources.srcs,
            includes = _include_paths(ctx, ctx.attr.includes, transitive_includes),
        ),
    ]

perl_library = rule(
    attrs = _LIBRARY_PERL_ATTRS,
    implementation = _perl_library_implementation,
    toolchains = ["@rules_perl//perl:toolchain_type"],
)

def _get_main_from_sources(ctx):
    sources = ctx.files.srcs
    if len(sources) != 1:
        fail("Cannot infer main from multiple 'srcs'. Please specify 'main' attribute.", "main")
    return sources[0]

def _env_vars(ctx):
    environment = {}
    for name, value in ctx.attr.env.items():
        environment[name] = ctx.expand_location(value, targets = ctx.attr.data)
    return environment

def _rlocationpath(file, workspace_name):
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]

    return "{}/{}".format(workspace_name, file.short_path)

def _perl_binary_implementation(ctx):
    toolchain = ctx.toolchains["@rules_perl//perl:toolchain_type"].perl_runtime
    interpreter = toolchain.interpreter

    main = ctx.file.main
    if main == None:
        main = _get_main_from_sources(ctx)

    extension = ""
    workspace_name = ctx.label.workspace_name
    if not workspace_name:
        workspace_name = ctx.workspace_name
    if not workspace_name:
        workspace_name = "_main"

    include_paths = depset([workspace_name], transitive = [dep[PerlInfo].includes for dep in ctx.attr.deps])

    is_windows = ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])
    if is_windows:
        extension = ".bat"

    output = ctx.actions.declare_file("{}{}".format(ctx.label.name, extension))
    config = ctx.actions.declare_file("{}.config.json".format(ctx.label.name))
    transitive_sources = _transitive_deps(
        ctx,
        extra_files = toolchain.runtime.to_list() + [
            ctx.file._entrypoint,
            output,
            config,
        ],
    )

    ctx.actions.write(
        output = config,
        content = json.encode_indent({
            "includes": include_paths.to_list(),
            "runfiles": [
                _rlocationpath(src, ctx.workspace_name)
                for src in depset(transitive = [transitive_sources.srcs, toolchain.runtime]).to_list()
            ],
        }),
    )

    ctx.actions.expand_template(
        template = ctx.file._wrapper_template,
        output = output,
        substitutions = {
            "{config}": _rlocationpath(config, ctx.workspace_name),
            "{entrypoint}": _rlocationpath(ctx.file._entrypoint, ctx.workspace_name),
            "{interpreter}": _rlocationpath(interpreter, ctx.workspace_name),
            "{main}": _rlocationpath(main, ctx.workspace_name),
        },
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = output,
            files = depset([output]),
            runfiles = transitive_sources.files,
        ),
        RunEnvironmentInfo(
            environment = _env_vars(ctx),
        ),
    ]

def _perl_test_implementation(ctx):
    return _perl_binary_implementation(ctx)

perl_binary = rule(
    attrs = _EXECUTABLE_PERL_ATTRS,
    executable = True,
    implementation = _perl_binary_implementation,
    toolchains = ["@rules_perl//perl:toolchain_type"],
)

perl_test = rule(
    attrs = _EXECUTABLE_PERL_ATTRS,
    executable = True,
    test = True,
    implementation = _perl_test_implementation,
    toolchains = ["@rules_perl//perl:toolchain_type"],
)
