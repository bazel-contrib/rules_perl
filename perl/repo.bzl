def _perl_download_impl(ctx):
    ctx.report_progress("Downloading perl")

    ctx.download_and_extract(
        ctx.attr.urls,
        sha256 = ctx.attr.sha256,
        stripPrefix = ctx.attr.strip_prefix,
    )

    ctx.report_progress("Creating Perl toolchain files")
    if ctx.attr.os == "darwin":
        os_constraint = "@platforms//os:osx"
    elif ctx.attr.os == "linux":
        os_constraint = "@platforms//os:linux"
    elif ctx.attr.os == "windows":
        os_constraint = "@platforms//os:windows"
    else:
        fail("Unsupported OS: " + ctx.attr.os)

    if ctx.attr.arch == "amd64":
        arch_constraint = "@platforms//cpu:x86_64"
    else:
        fail("Unsupported arch: " + ctx.attr.arch)

    constraints = [os_constraint, arch_constraint]
    constraint_str = ",\n        ".join(['"%s"' % c for c in constraints])

    substitutions = {
        "{exec_constraints}": constraint_str,
    }
    ctx.template(
        "BUILD.bazel",
        ctx.attr._build_tpl,
        substitutions = substitutions,
    )

perl_download = repository_rule(
    implementation = _perl_download_impl,
    attrs = {
        "urls": attr.string_list(
            mandatory = True,
            doc = "List of mirror URLs where a Perl distribution archive can be downloaded",
        ),
        "sha256": attr.string(
            mandatory = True,
            doc = "Expected SHA-256 sum of the downloaded archive",
        ),
        "os": attr.string(
            mandatory = True,
            values = ["darwin", "linux", "windows"],
            doc = "Host operating system for the Perl distribution",
        ),
        "arch": attr.string(
            mandatory = True,
            values = ["amd64"],
            doc = "Host architecture for the Perl distribution",
        ),
        # TODO - This only works for perl from a download
        # perl built in a tree or system perl would hate this
        "strip_prefix": attr.string(
            mandatory = True,
            doc = "Prefix to strip from perl distr tarballs",
        ),
        "_build_tpl": attr.label(
            default = "@rules_perl//perl/private:BUILD.dist.bazel.tpl",
        ),
    },
    doc = "Downloads a standard Perl distribution and installs a build file",
)
