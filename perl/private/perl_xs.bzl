"""Perl XS rules for Bazel"""

load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_cc//cc:defs.bzl", "CcInfo", "cc_common")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain")
load(":perl_tool.bzl", "PerlToolInfo")

_MACOS_LINKOPTS = [
    "-undefined",
    "dynamic_lookup",
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
        # The interpreter's own flags first, as MakeMaker does: ccflags carries
        # ABI-affecting defines that config.h does not (the locale model on
        # macOS, for one), and an object compiled without them fails perl's
        # load-time handshake ("loadable library and perl binaries are
        # mismatched"). cccdlflags is -fPIC where the platform needs it.
        user_compile_flags = toolchain.ccflags + toolchain.cccdlflags + ctx.attr.copts,
        compilation_contexts = [],
    )

    linkopts = list(ctx.attr.linkopts)
    if ctx.target_platform_has_constraint(
        ctx.attr._macos_constraint[platform_common.ConstraintValueInfo],
    ):
        linkopts.extend(_MACOS_LINKOPTS)

    (linking_context, _linking_outputs) = cc_common.create_linking_context_from_compilation_outputs(
        actions = ctx.actions,
        name = ctx.label.name,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        compilation_outputs = compilation_outputs,
        user_link_flags = linkopts,
        linking_contexts = [],
    )

    return CcInfo(
        compilation_context = compilation_context,
        linking_context = linking_context,
    )

def _perl_xs_implementation(ctx):
    toolchain = ctx.toolchains["@rules_perl//perl:toolchain_type"].perl_runtime

    if not toolchain.supports_xs:
        fail((
            "{}: the resolved perl toolchain does not support XS"
        ).format(ctx.label))

    xsubpp = ctx.attr._xsubpp[PerlToolInfo]

    gen = []
    cc_infos = []

    for src in ctx.files.srcs:
        c_execpath = paths.replace_extension(src.path, ".c")
        o_packagepath = paths.join("_objs/execroot/", c_execpath)
        out = ctx.actions.declare_file(o_packagepath)

        args = ctx.actions.args()
        args.add(xsubpp.main)
        args.add_all(ctx.files.typemaps, before_each = "--typemap")
        args.add("--output", out)
        args.add(src)

        ctx.actions.run(
            mnemonic = "PerlTranslitterate",
            outputs = [out],
            inputs = [src] + ctx.files.typemaps,
            arguments = [args],
            progress_message = "Translitterating %s to %s" % (src.short_path, out.short_path),
            executable = xsubpp.interpreter,
            tools = xsubpp.tools,
            execution_requirements = {"supports-path-mapping": "1"},
            toolchain = None,
        )

        gen.append(out)

    cc_info = _perl_xs_cc_lib(ctx, toolchain, gen)
    cc_infos = [cc_info] + [dep[CcInfo] for dep in ctx.attr.deps]
    cc_info = cc_common.merge_cc_infos(cc_infos = cc_infos)
    lib = cc_info.linking_context.linker_inputs.to_list()[0].libraries[0]
    dyn_lib = lib.dynamic_library

    is_macos = ctx.target_platform_has_constraint(
        ctx.attr._macos_constraint[platform_common.ConstraintValueInfo],
    )
    ext = ".bundle" if is_macos else ".so"
    if ctx.attr.output_loc:
        output_loc = ctx.attr.output_loc
        if "." not in paths.basename(output_loc):
            output_loc = output_loc + ext
        output = ctx.actions.declare_file(output_loc)
    else:
        output = ctx.actions.declare_file(ctx.label.name + ext)

    ctx.actions.symlink(
        output = output,
        target_file = dyn_lib,
    )

    return [
        cc_info,
        DefaultInfo(files = depset([output])),
    ]

perl_xs = rule(
    doc = """Builds a Perl XS extension as a loadable shared object.

    Translates `.xs` sources to C via xsubpp, compiles and links them (with optional
    extra C/C++ sources and typemaps), and produces a single shared library suitable
    for loading with `DynaLoader` / `use` from Perl.
    """,
    attrs = {
        "cc_srcs": attr.label_list(
            doc = "Additional C or C++ source files compiled and linked into the extension.",
            allow_files = [".c", ".cc"],
        ),
        "copts": attr.string_list(
            doc = "Extra compiler flags passed to the C/C++ compilation.",
        ),
        "defines": attr.string_list(
            doc = "Preprocessor defines (e.g. -DNAME or -DNAME=value) for compilation.",
        ),
        "deps": attr.label_list(
            doc = "Targets providing CcInfo (e.g. cc_library) to link with the extension.",
            providers = [CcInfo],
        ),
        "linkopts": attr.string_list(
            doc = "Extra linker flags passed when linking the shared library.",
        ),
        "output_loc": attr.string(
            doc = "Optional output path for the shared library. If the basename contains " +
                  "no `.`, the platform extension (`.so` on Linux, `.bundle` on macOS) is " +
                  "appended automatically. Defaults to `<target_name>.so` on Linux or " +
                  "`<target_name>.bundle` on macOS.",
        ),
        "srcs": attr.label_list(
            doc = "Perl XS (.xs) source files. Each is translated to C by xsubpp and then compiled.",
            allow_files = [".xs"],
        ),
        "textual_hdrs": attr.label_list(
            doc = "Header files included in the build. Their directories are added to the include path.",
            allow_files = True,
        ),
        "typemaps": attr.label_list(
            doc = "Typemap files used by xsubpp when translating XS.",
            allow_files = True,
        ),
        "_macos_constraint": attr.label(
            default = Label("@platforms//os:macos"),
        ),
        "_xsubpp": attr.label(
            cfg = "exec",
            providers = [PerlToolInfo],
            default = Label("//perl/private:xsubpp"),
        ),
    },
    implementation = _perl_xs_implementation,
    fragments = ["cpp"],
    toolchains = [
        "@rules_perl//perl:toolchain_type",
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
)
