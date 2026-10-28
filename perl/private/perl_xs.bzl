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

# Compilers driven by cl.exe's command line: as Bazel names them in
# CcToolchainInfo.compiler (@rules_cc//cc/compiler uses the same names), and
# as %Config names them in cc.
_MSVC_COMPILERS = ["msvc-cl", "clang-cl", "cl"]

def _has_constraint(ctx, constraint):
    return ctx.target_platform_has_constraint(constraint[platform_common.ConstraintValueInfo])

def _is_msvc(compiler):
    """Whether a compiler name, Bazel's or %Config's, is one driven like cl.exe."""
    return compiler in _MSVC_COMPILERS

def _compile_flags(toolchain, cc_toolchain, is_windows):
    """The interpreter's own compile flags, in the resolved compiler's dialect.

    MakeMaker compiles every XS object with $Config{ccflags}: they carry
    ABI-affecting defines that config.h does not (the locale model on macOS,
    for one), and an object compiled without them fails perl's load-time
    handshake ("loadable library and perl binaries are mismatched").
    cccdlflags is -fPIC where the platform needs it.
    """
    ccflags = toolchain.ccflags
    if is_windows and toolchain.cc and _is_msvc(toolchain.cc) != _is_msvc(cc_toolchain.compiler):
        # Windows has two compiler families, and a perl's ccflags are in the
        # dialect of the one that built it: MinGW gcc for Strawberry Perl,
        # cl.exe for an MSVC build. Across families the defines are the part
        # that matters, and both compilers take -D. The rest tune the dialect
        # and code generation (-std=c99, -fwrapv; -nologo, -MD) or ask gcc for
        # the struct layout cl.exe has natively (-mms-bitfields, mingw-w64's
        # default anyway). Both families' perls use the UCRT, so an XS object
        # from either shares the interpreter's C runtime.
        ccflags = [flag for flag in ccflags if flag.startswith("-D")]
        if _is_msvc(cc_toolchain.compiler):
            # A gcc-built config.h spells PERL_STATIC_INLINE with gcc's
            # inline keyword, which cl.exe knows as __inline.
            ccflags.append("-D__inline__=__inline")
    return ccflags + toolchain.cccdlflags

def _dlext(toolchain, is_windows, is_macos):
    """The extension DynaLoader looks for, with its leading dot."""
    if toolchain.dlext:
        return "." + toolchain.dlext

    # A hand-written perl_toolchain that does not say: the platform's usual.
    if is_windows:
        return ".dll"
    if is_macos:
        return ".bundle"
    return ".so"

def _libperl(ctx, toolchain):
    """Perl's import library.

    A Windows DLL must resolve every symbol it imports when it is linked;
    none can be left for the loading interpreter to supply, as ELF allows by
    default and Mach-O on request (-undefined dynamic_lookup). So an XS
    object links against the import library of perl's own DLL, as MakeMaker's
    PERL_ARCHIVE has it do.
    """
    if toolchain.libperl == None:
        fail((
            "{}: the resolved perl toolchain has no import library for perl's shared " +
            "library (perl_toolchain.libperl), which an XS object on Windows must link against"
        ).format(ctx.label))
    return toolchain.libperl

def _boot_def_file(ctx, srcs):
    """A module-definition file exporting the boot XSUBs of the translated sources.

    A DLL exports nothing unless told to, and the boot XSUB is the one symbol
    DynaLoader must find in it. See xs_def.pl.
    """
    xs_def = ctx.attr._xs_def[PerlToolInfo]
    out = ctx.actions.declare_file(ctx.label.name + ".def")

    args = ctx.actions.args()
    args.add(xs_def.main)
    args.add("--output", out)
    args.add_all(srcs)

    ctx.actions.run(
        mnemonic = "PerlXsDef",
        outputs = [out],
        inputs = srcs,
        arguments = [args],
        progress_message = "Listing XS exports for %s" % out.short_path,
        executable = xs_def.interpreter,
        tools = xs_def.tools,
        execution_requirements = {"supports-path-mapping": "1"},
        toolchain = None,
    )

    return out

def _perl_xs_cc_lib(ctx, toolchain, srcs, is_windows, is_macos):
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
        # The interpreter's own flags first, as MakeMaker does.
        user_compile_flags = _compile_flags(toolchain, cc_toolchain, is_windows) + ctx.attr.copts,
        compilation_contexts = [],
    )

    linkopts = list(ctx.attr.linkopts)
    additional_inputs = []
    variables_extension = {}
    if is_macos:
        linkopts.extend(_MACOS_LINKOPTS)
    if is_windows:
        # Both link.exe and gcc take an archive by path.
        libperl = _libperl(ctx, toolchain)
        additional_inputs.append(libperl)
        linkopts.append(libperl.path)

        # The cc toolchain's def_file feature turns this into link.exe's /DEF:,
        # as it does for cc_library's generated .def file. MinGW's gcc exports
        # every symbol of a DLL by default and has no such feature to consume it.
        def_file = _boot_def_file(ctx, srcs)
        additional_inputs.append(def_file)
        variables_extension["def_file_path"] = def_file.path

    # A finished shared object with its deps linked in, as cc_binary links one
    # with linkshared: the c++-link-dynamic-library action. The cc_library
    # flavour (create_linking_context_from_compilation_outputs) links a
    # "nodeps" library, which leaves deps out and is an action not every
    # toolchain configures; the macOS one from rules_cc does not.
    linking_outputs = cc_common.link(
        actions = ctx.actions,
        name = ctx.label.name,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        compilation_outputs = compilation_outputs,
        user_link_flags = linkopts,
        linking_contexts = [dep[CcInfo].linking_context for dep in ctx.attr.deps],
        additional_inputs = additional_inputs,
        variables_extension = variables_extension,
        output_type = "dynamic_library",
    )

    return CcInfo(
        compilation_context = compilation_context,
        linking_context = cc_common.create_linking_context(
            linker_inputs = depset([cc_common.create_linker_input(
                owner = ctx.label,
                libraries = depset([linking_outputs.library_to_link]),
            )]),
        ),
    )

def _perl_xs_implementation(ctx):
    toolchain = ctx.toolchains["@rules_perl//perl:toolchain_type"].perl_runtime

    # Left to the target to avoid by marking itself incompatible (see the rule
    # doc); a private dependency on an incompatible target could do that for
    # every perl_xs, but whether to skip or fail is the build's call.
    if not toolchain.supports_xs:
        fail((
            "{}: the resolved perl toolchain cannot load XS (a fully static perl, or one " +
            "without Config_heavy.pl). On Linux set --@rules_perl//perl/settings:xs=true; " +
            "see perl_xs for skipping XS targets under the default."
        ).format(ctx.label))

    is_windows = _has_constraint(ctx, ctx.attr._windows_constraint)
    is_macos = _has_constraint(ctx, ctx.attr._macos_constraint)

    xsubpp = ctx.attr._xsubpp[PerlToolInfo]

    gen = []

    for src in ctx.files.srcs:
        # The source's exec path under a directory of our own keeps the
        # generated files of different packages apart. The directory must not
        # be called "execroot": on Windows, Bazel reads gcc's dependency files
        # for MSYS-style absolute paths by looking for that word, and would
        # re-root the path after it.
        c_execpath = paths.replace_extension(src.path, ".c")
        out = ctx.actions.declare_file(paths.join("_xs", c_execpath))

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

    cc_info = _perl_xs_cc_lib(ctx, toolchain, gen, is_windows, is_macos)
    lib = cc_info.linking_context.linker_inputs.to_list()[0].libraries[0]
    dyn_lib = lib.dynamic_library

    ext = _dlext(toolchain, is_windows, is_macos)
    if ctx.attr.output_loc:
        output_loc = ctx.attr.output_loc
        if "." not in paths.basename(output_loc):
            output_loc = output_loc + ext
    else:
        output_loc = ctx.label.name + ext

    # cc_common.link names the library itself: lib<name>.so, lib<name>.dylib or,
    # on Windows, <name>.dll, which with a plain `dll` dlext is already the
    # wanted name. A second file at that path would be a conflicting action,
    # so the linked file is then the output; otherwise it is symlinked into
    # place.
    if dyn_lib.path == paths.join(ctx.bin_dir.path, ctx.label.workspace_root, ctx.label.package, output_loc):
        output = dyn_lib
    else:
        output = ctx.actions.declare_file(output_loc)
        ctx.actions.symlink(output = output, target_file = dyn_lib)

    return [
        cc_info,
        DefaultInfo(files = depset([output])),
    ]

perl_xs = rule(
    doc = """Builds a Perl XS extension as a loadable shared object.

    Translates `.xs` sources to C via xsubpp, compiles and links them (with optional
    extra C/C++ sources and typemaps), and produces a single shared library suitable
    for loading with `DynaLoader` / `use` from Perl.

    The object is named with the toolchain's `$Config{dlext}`: `.so` on Linux,
    `.bundle` on macOS, `.xs.dll` for Strawberry Perl on Windows. On Windows it is
    linked against the import library of perl's own DLL and exports its boot XSUB,
    as MakeMaker arranges. The C toolchain may be MSVC (`cl.exe`, Bazel's default)
    or MinGW gcc whichever of the two the perl was built with; across families the
    interpreter's compile flags are reduced to their defines.

    By default (`--@rules_perl//perl/settings:xs=false`) Linux resolves a static
    perl that cannot load XS; a build with XS sets the flag on. A target that
    needs XS can be skipped by wildcard builds that leave it off by marking it,
    and so everything that depends on it, incompatible:

    ```python
    target_compatible_with = select({
        "@rules_perl//perl/settings:xs_disabled": ["@platforms//:incompatible"],
        "//conditions:default": [],
    }),
    ```
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
                  "no `.`, the toolchain's extension (`$Config{dlext}`: `.so` on Linux, " +
                  "`.bundle` on macOS, `.xs.dll` for Strawberry Perl) is appended " +
                  "automatically. Defaults to `<target_name>` plus that extension.",
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
        "_windows_constraint": attr.label(
            default = Label("@platforms//os:windows"),
        ),
        "_xs_def": attr.label(
            cfg = "exec",
            providers = [PerlToolInfo],
            default = Label("//perl/private:xs_def"),
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
