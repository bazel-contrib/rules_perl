"""Rules for downloading hermetic Perl binaries"""

def _find_file(root, name, max_depth):
    """Breadth-first search for a file called `name` under `root`."""
    frontier = [root]
    for _ in range(max_depth):
        deeper = []
        for directory in frontier:
            for entry in directory.readdir():
                if entry.basename == name:
                    return entry
                if entry.is_dir:
                    deeper.append(entry)
        frontier = deeper
    return None

def _config_value(config_sh, key):
    """The value of `key='...'` in Config_heavy.pl's embedded config.sh, or "" if absent."""
    marker = "\n{}='".format(key)
    start = config_sh.find(marker)
    if start < 0:
        return ""
    start += len(marker)
    return config_sh[start:config_sh.index("'", start)]

def _config_flags(config_sh, key):
    """A whitespace-separated %Config value as a list of flags."""
    return [flag for flag in _config_value(config_sh, key).split(" ") if flag]

def _perl_download_impl(ctx):
    ctx.report_progress("Downloading perl")

    ctx.download_and_extract(
        ctx.attr.urls,
        sha256 = ctx.attr.sha256,
        stripPrefix = ctx.attr.strip_prefix,
    )

    # The flags XS modules must be compiled with live in %Config, not in
    # config.h (see PerlRuntimeInfo.ccflags); MakeMaker applies them to every
    # XS compile, so must perl_xs. Config_heavy.pl is plain text, so this needs
    # no perl to run -- the archive may be for another platform.
    #
    # Every perl since 5.8.1 ships Config_heavy.pl, but a trimmed-down
    # distribution may have dropped it. Such a perl cannot build XS by any
    # means (MakeMaker reads the same file) but still runs pure-Perl targets,
    # so a missing file only makes supports_xs false; perl_xs reports that.
    ctx.report_progress("Reading %Config")
    config_heavy = _find_file(ctx.path("."), "Config_heavy.pl", max_depth = 6)
    config_sh = ctx.read(config_heavy) if config_heavy else ""

    ctx.report_progress("Creating Perl toolchain files")
    ctx.template(
        "BUILD.bazel",
        ctx.attr._build_tpl,
        substitutions = {
            "{cccdlflags}": repr(_config_flags(config_sh, "cccdlflags")),
            "{ccflags}": repr(_config_flags(config_sh, "ccflags")),
            # A perl without dynamic loading (the fully static builds) cannot
            # load XS built after it.
            "{supports_xs}": repr(_config_value(config_sh, "usedl") == "define"),
        },
    )

perl_download = repository_rule(
    implementation = _perl_download_impl,
    attrs = {
        "sha256": attr.string(
            mandatory = True,
            doc = "Expected SHA-256 sum of the downloaded archive",
        ),
        # TODO - This only works for perl from a download
        # perl built in a tree or system perl would hate this
        "strip_prefix": attr.string(
            mandatory = True,
            doc = "Prefix to strip from perl distr tarballs",
        ),
        "urls": attr.string_list(
            mandatory = True,
            doc = "List of mirror URLs where a Perl distribution archive can be downloaded",
        ),
        "_build_tpl": attr.label(
            default = Label("@rules_perl//perl/private:BUILD.dist.bazel.tpl"),
        ),
    },
    doc = "Downloads a standard Perl distribution and installs a build file",
)
