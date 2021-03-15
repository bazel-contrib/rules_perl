# Copyright 2015 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Perl rules for Bazel"""

load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_cc//cc:toolchain_utils.bzl", "find_cpp_toolchain")
load("@rules_cc//cc:action_names.bzl", "C_COMPILE_ACTION_NAME")

PerlLibrary = provider(fields = ["transitive_perl_sources"])

PERL_XS_COPTS = [
    "-fwrapv",
    "-fPIC",
    "-fno-strict-aliasing",
    "-D_LARGEFILE_SOURCE",
    "-D_FILE_OFFSET_BITS=64",
]

_perl_file_types = [".pl", ".pm", ".t", ".so", ".ix", ".al"]
_perl_srcs_attr = attr.label_list(allow_files = _perl_file_types)

_perl_deps_attr = attr.label_list(
    allow_files = False,
    providers = [PerlLibrary],
)

_perl_data_attr = attr.label_list(
    allow_files = True,
)

_perl_main_attr = attr.label(
    allow_single_file = _perl_file_types,
)

_perl_env_attr = attr.string_dict()

def _get_main_from_sources(ctx):
    sources = ctx.files.srcs
    if len(sources) != 1:
        fail("Cannot infer main from multiple 'srcs'. Please specify 'main' attribute.", "main")
    return sources[0]

def _transitive_srcs(deps):
    return struct(
        srcs = [
            d[PerlLibrary].transitive_perl_sources
            for d in deps
            if PerlLibrary in d
        ],
        data_files = [d[DefaultInfo].data_runfiles.files for d in deps],
        default_files = [d[DefaultInfo].default_runfiles.files for d in deps],
    )

def transitive_deps(ctx, extra_files = [], extra_deps = []):
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
    files = depset(extra_files + ctx.files.srcs)
    default_files = ctx.runfiles(
        files = files.to_list(),
        transitive_files = depset(transitive = deps.default_files),
        collect_default = True,
    )
    data_files = ctx.runfiles(
        files = ctx.files.data,
        transitive_files = depset(transitive = deps.data_files),
        collect_data = True,
    )
    return struct(
        srcs = depset(
            direct = ctx.files.srcs,
            transitive = deps.srcs,
        ),
        default_files = default_files,
        data_files = data_files,
    )

def _perl_library_implementation(ctx):
    transitive_sources = transitive_deps(ctx)
    return [
        DefaultInfo(
            default_runfiles = transitive_sources.default_files,
            data_runfiles = transitive_sources.data_files,
        ),
        PerlLibrary(
            transitive_perl_sources = transitive_sources.srcs,
        ),
    ]

def _perl_binary_implementation(ctx):
    toolchain = ctx.toolchains["@rules_perl//:toolchain_type"].perl_runtime
    interpreter = toolchain.interpreter

    transitive_sources = transitive_deps(ctx, extra_files = toolchain.runtime + [ctx.outputs.executable])

    main = ctx.file.main
    if main == None:
        main = _get_main_from_sources(ctx)

    ctx.actions.expand_template(
        template = ctx.file._wrapper_template,
        output = ctx.outputs.executable,
        substitutions = {
            "{env_vars}": _env_vars(ctx),
            "{interpreter}": interpreter.short_path,
            "{main}": main.short_path,
            "{workspace_name}": ctx.label.workspace_name or ctx.workspace_name,
        },
        is_executable = True,
    )

    return DefaultInfo(
        executable = ctx.outputs.executable,
        default_runfiles = transitive_sources.default_files,
        data_runfiles = transitive_sources.data_files,
    )

def _env_vars(ctx):
    environment = ""
    for name, value in ctx.attr.env.items():
        if not _is_identifier(name):
            fail("%s is not a valid environment variable name." % str(name))
        environment += ("{key}='{value}' ").format(
            key = name,
            value = value.replace("'", "\\'"),
        )
    return environment

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

def _perl_test_implementation(ctx):
    return _perl_binary_implementation(ctx)

def _perl_xs_cc_lib(ctx, toolchain, srcs):
    cc_toolchain = find_cpp_toolchain(ctx)
    xs_headers = toolchain.xs_headers

    includes = [f.dirname for f in xs_headers.to_list()]

    textual_hdrs = []
    for hdrs in ctx.attr.textual_hdrs:
        for hdr in hdrs.files.to_list():
            textual_hdrs.append(hdr)
            includes.append(hdr.dirname)

    includes = sets.make(includes)
    includes = sets.to_list(includes)

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    (compilation_context, compilation_outputs) = cc_common.compile(
        actions = ctx.actions,
        name = ctx.label.name,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        srcs = srcs,
        defines = ctx.attr.defines,
        additional_inputs = textual_hdrs,
        private_hdrs = xs_headers.to_list(),
        includes = includes,
        user_compile_flags = ctx.attr.copts + PERL_XS_COPTS,
        compilation_contexts = [],
    )

    (linking_context, linking_outputs) = cc_common.create_linking_context_from_compilation_outputs(
        actions = ctx.actions,
        name = ctx.label.name,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        compilation_outputs = compilation_outputs,
        linking_contexts = [],
    )

    return CcInfo(
        compilation_context = compilation_context,
        linking_context = linking_context,
    )

def _perl_xs_implementation(ctx):
    toolchain = ctx.toolchains["@rules_perl//:toolchain_type"].perl_runtime
    xsubpp = toolchain.xsubpp

    toolchain_files = depset(toolchain.runtime)
    trans_runfiles = [toolchain_files]

    gen = []
    cc_infos = []
    args_typemaps = []

    for typemap in ctx.files.typemaps:
        args_typemaps += ["-typemap", typemap.short_path]

    for src in ctx.files.srcs:
        out = ctx.actions.declare_file(paths.replace_extension(src.path, ".c"))
        name = "%s_c" % src.basename

        ctx.actions.run(
            outputs = [out],
            inputs = [src] + ctx.files.typemaps,
            arguments = args_typemaps + ["-output", out.path, src.path],
            progress_message = "Translitterating %s to %s" % (src.short_path, out.short_path),
            executable = xsubpp,
            tools = toolchain_files,
        )

        gen.append(out)

    cc_info = _perl_xs_cc_lib(ctx, toolchain, gen)
    cc_infos = [cc_info] + [dep[CcInfo] for dep in ctx.attr.deps]
    cc_info = cc_common.merge_cc_infos(cc_infos = cc_infos)
    lib = cc_info.linking_context.linker_inputs.to_list()[0].libraries[0]
    dyn_lib = lib.dynamic_library

    if len(ctx.attr.output_loc):
        output = ctx.actions.declare_file(ctx.attr.output_loc)
    else:
        output = ctx.actions.declare_file(ctx.label.name + ".so")

    ctx.actions.run_shell(
        outputs = [output],
        inputs = [dyn_lib],
        arguments = [dyn_lib.path, output.path],
        command = "cp $1 $2",
    )

    return [
        cc_info,
        DefaultInfo(files = depset([output])),
    ]

perl_library = rule(
    attrs = {
        "srcs": _perl_srcs_attr,
        "deps": _perl_deps_attr,
        "data": _perl_data_attr,
    },
    implementation = _perl_library_implementation,
    toolchains = ["@rules_perl//:toolchain_type"],
)

perl_binary = rule(
    attrs = {
        "srcs": _perl_srcs_attr,
        "deps": _perl_deps_attr,
        "data": _perl_data_attr,
        "env": _perl_env_attr,
        "main": _perl_main_attr,
        "_wrapper_template": attr.label(
            allow_single_file = True,
            default = "binary_wrapper.tpl",
        ),
    },
    executable = True,
    implementation = _perl_binary_implementation,
    toolchains = ["@rules_perl//:toolchain_type"],
)

perl_test = rule(
    attrs = {
        "srcs": _perl_srcs_attr,
        "deps": _perl_deps_attr,
        "data": _perl_data_attr,
        "main": _perl_main_attr,
        "env": _perl_env_attr,
        "_wrapper_template": attr.label(
            allow_single_file = True,
            default = "binary_wrapper.tpl",
        ),
    },
    executable = True,
    test = True,
    implementation = _perl_test_implementation,
    toolchains = ["@rules_perl//:toolchain_type"],
)

perl_xs = rule(
    attrs = {
        "srcs": attr.label_list(allow_files = [".xs"]),
        "textual_hdrs": attr.label_list(allow_files = True),
        "typemaps": attr.label_list(allow_files=True),
        "output_loc": attr.string(),
        "defines": attr.string_list(),
        "copts": attr.string_list(),
        "deps": attr.label_list(providers = [CcInfo]),
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
    },
    implementation = _perl_xs_implementation,
    fragments = ["cpp"],
    toolchains = [
        "@rules_perl//:toolchain_type",
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
)
