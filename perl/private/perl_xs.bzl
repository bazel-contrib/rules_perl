"""Perl XS rules for Bazel"""

load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_cc//cc:defs.bzl", "CcInfo", "cc_common")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain")

_PERL_XS_COPTS = [
    "-fwrapv",
    "-fPIC",
    "-fno-strict-aliasing",
    "-D_LARGEFILE_SOURCE",
    "-D_FILE_OFFSET_BITS=64",
]

def _perl_xs_cc_lib(ctx, toolchain, srcs):
    cc_toolchain = find_cc_toolchain(ctx)
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
        srcs = srcs + ctx.files.cc_srcs,
        defines = ctx.attr.defines,
        additional_inputs = textual_hdrs,
        private_hdrs = xs_headers.to_list(),
        includes = includes,
        user_compile_flags = ctx.attr.copts + _PERL_XS_COPTS,
        compilation_contexts = [],
    )

    (linking_context, _linking_outputs) = cc_common.create_linking_context_from_compilation_outputs(
        actions = ctx.actions,
        name = ctx.label.name,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        compilation_outputs = compilation_outputs,
        user_link_flags = ctx.attr.linkopts,
        linking_contexts = [],
    )

    return CcInfo(
        compilation_context = compilation_context,
        linking_context = linking_context,
    )

def _perl_xs_implementation(ctx):
    toolchain = ctx.toolchains["@rules_perl//perl:toolchain_type"].perl_runtime
    xsubpp = toolchain.xsubpp

    toolchain_files = toolchain.runtime

    gen = []
    cc_infos = []

    for src in ctx.files.srcs:
        c_execpath = paths.replace_extension(src.path, ".c")
        o_packagepath = paths.join("_objs/execroot/", c_execpath)
        out = ctx.actions.declare_file(o_packagepath)

        # typemap paths are resolved relative to their src.
        src_dir = paths.dirname(src.path)
        args_typemaps_relative = []
        for typemap in ctx.files.typemaps:
            # Calculate the relative path from the src directory to the typemap path
            relative_typemap_path = paths.relativize(typemap.path, src_dir)
            args_typemaps_relative += ["-typemap", relative_typemap_path]

        ctx.actions.run(
            outputs = [out],
            inputs = [src] + ctx.files.typemaps,
            arguments = args_typemaps_relative + ["-output", out.path, src.path],
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

perl_xs = rule(
    attrs = {
        "cc_srcs": attr.label_list(allow_files = [".c", ".cc"]),
        "copts": attr.string_list(),
        "defines": attr.string_list(),
        "deps": attr.label_list(providers = [CcInfo]),
        "linkopts": attr.string_list(),
        "output_loc": attr.string(),
        "srcs": attr.label_list(allow_files = [".xs"]),
        "textual_hdrs": attr.label_list(allow_files = True),
        "typemaps": attr.label_list(allow_files = True),
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
    },
    implementation = _perl_xs_implementation,
    fragments = ["cpp"],
    toolchains = [
        "@rules_perl//perl:toolchain_type",
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
)
