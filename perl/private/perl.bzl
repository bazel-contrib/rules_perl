"""Perl rules for Bazel"""

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
    return struct(
        srcs = depset(
            direct = ctx.files.srcs,
            transitive = deps.srcs,
        ),
        files = files,
    )

def _include_paths(ctx):
    """Calculate the PERL5LIB paths for a perl_library rule's includes."""
    workspace_name = ctx.label.workspace_name
    if workspace_name:
        workspace_root = "../" + workspace_name
    else:
        workspace_root = ""
    package_root = (workspace_root + "/" + ctx.label.package).strip("/") or "."
    include_paths = [package_root] if "." in ctx.attr.includes else []
    include_paths.extend([package_root + "/" + include for include in ctx.attr.includes if include != "."])
    for dep in ctx.attr.deps:
        include_paths.extend(dep[PerlInfo].includes)
    include_paths = depset(direct = include_paths).to_list()
    return include_paths

def _perl_library_implementation(ctx):
    transitive_sources = _transitive_deps(ctx)
    return [
        DefaultInfo(
            runfiles = transitive_sources.files,
        ),
        PerlInfo(
            transitive_perl_sources = transitive_sources.srcs,
            includes = _include_paths(ctx),
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

def _is_identifier(name):
    # Must be non-empty.
    if name == None or len(name) == 0:
        return False

    # Must start with alpha or '_'
    if not (name[0].isalpha() or name[0] == "_"):
        return False

    # Must consist of alnum characters or '_'s.
    for c in name.elems():
        if not (c.isalnum() or c == "_"):
            return False
    return True

def _env_vars(ctx, is_windows):
    environment = ""
    template = "{key}='{value}' "
    if is_windows:
        template = "set {key}={value}\n"
    for name, value in ctx.attr.env.items():
        if not _is_identifier(name):
            fail("%s is not a valid environment variable name." % str(name))
        value = ctx.expand_location(value, targets = ctx.attr.data)
        environment += template.format(
            key = name,
            value = value.replace("'", "\\'"),
        )
    return environment

def _perl_binary_implementation(ctx):
    toolchain = ctx.toolchains["@rules_perl//perl:toolchain_type"].perl_runtime
    interpreter = toolchain.interpreter

    main = ctx.file.main
    if main == None:
        main = _get_main_from_sources(ctx)

    extension = ""
    path_sep = ":"
    path_prefix = "${PATH_PREFIX}"
    interpreter_path = interpreter.short_path
    main_path = main.short_path
    workspace_name = ctx.label.workspace_name
    if not workspace_name:
        workspace_name = ctx.workspace_name
    if not workspace_name:
        workspace_name = "_main"

    include_paths = [""]
    for dep in ctx.attr.deps:
        include_paths.extend(dep[PerlInfo].includes)

    is_windows = ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])
    if is_windows:
        path_sep = ";"
        path_prefix = "%PATH_PREFIX%"
        extension = ".bat"
        interpreter_path = interpreter_path.replace("/", "\\")
        main_path = main_path.replace("/", "\\")
        include_paths = [p.replace("/", "\\") for p in include_paths]

    perl5lib = path_sep + path_sep.join(["{}{}".format(path_prefix, p) for p in include_paths]) if include_paths else ""

    output = ctx.actions.declare_file("{}{}".format(ctx.label.name, extension))
    transitive_sources = _transitive_deps(ctx, extra_files = toolchain.runtime + [output])

    ctx.actions.expand_template(
        template = ctx.file._wrapper_template,
        output = output,
        substitutions = {
            "{PERL5LIB}": perl5lib,
            "{env_vars}": _env_vars(ctx, is_windows),
            "{interpreter}": interpreter_path,
            "{main}": main_path,
            "{workspace_name}": workspace_name,
        },
        is_executable = True,
    )

    return DefaultInfo(
        executable = output,
        runfiles = transitive_sources.files,
    )

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
