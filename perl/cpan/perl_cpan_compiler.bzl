"""Rules for generating CPAN lock files"""

def _perl_cpan_compiler_impl(ctx):
    cpanfile = ctx.file.cpanfile
    lockfile = ctx.file.lockfile

    if not cpanfile.is_source:
        fail("`cpanfile` cannot be generated. Please update it to be a source file for {}".format(ctx.label))
    if not lockfile.is_source:
        fail("`lockfile` cannot be generated. Please update it to be a source file for {}".format(ctx.label))

    compiler = ctx.executable._compiler
    executable = ctx.actions.declare_file("{}.{}".format(ctx.label.name, compiler.extension).rstrip("."))
    ctx.actions.symlink(
        output = executable,
        target_file = compiler,
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [cpanfile]).merge(ctx.attr._compiler[DefaultInfo].default_runfiles)

    return [
        DefaultInfo(
            executable = executable,
            runfiles = runfiles,
        ),
        RunEnvironmentInfo(
            environment = {
                "PERL_CPAN_COMPILER_CPANFILE": cpanfile.short_path,
                "PERL_CPAN_COMPILER_LOCKFILE": lockfile.short_path,
            },
        ),
    ]

perl_cpan_compiler = rule(
    doc = """\
A rule for compiling a Bazel-compatible lock file from [cpanfile](https://metacpan.org/dist/Module-CPANfile/view/lib/cpanfile.pod)

Note that when setting this target up for the first time, an empty file will need to be generated at the label passed
to the `lockfile` attribute.
""",
    implementation = _perl_cpan_compiler_impl,
    attrs = {
        "cpanfile": attr.label(
            doc = "The `cpanfile` describing dependencies.",
            allow_single_file = ["cpanfile"],
            mandatory = True,
        ),
        "lockfile": attr.label(
            doc = "The location of the Bazel lock file.",
            allow_single_file = [".json"],
            mandatory = True,
        ),
        "_compiler": attr.label(
            executable = True,
            cfg = "target",
            default = Label("//perl/cpan/private:carton_compiler"),
        ),
    },
    executable = True,
)
