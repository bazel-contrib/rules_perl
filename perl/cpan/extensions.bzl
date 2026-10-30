"""Perl CPAN Extensions"""

load("//perl/cpan/private:carton.bzl", "create_repos", "plan_hubs")

_install_tag = tag_class(
    attrs = {
        "add_deps": attr.string_list_dict(
            doc = """
                Add dependencies to perl_* targets. Keys are packages, values are packages.

                Example:

                    add_deps = {"App-cloc": ["Parallel-ForkManager"]},
                """,
            default = {},
        ),
        "bins": attr.string_list_dict(
            doc = """
                Perl binary targets. Keys are packages, values are lists of bin paths.
                Each becomes `@<hub>//<package>:<bin path with `/` as `_`>`.

                Example:

                    bins = {"App-cloc": ["bin/cloc"]},

                gives `@<hub>//App-cloc:bin_cloc`.
                """,
            default = {},
        ),
        "lock": attr.label(
            doc = """
                The `cpanfile.snapshot` Carton writes, or the `.json` lock that `cpan_compiler`
                compiles from one.

                A snapshot has no hashes of the archives, so reading one needs a Bazel whose
                module extensions have facts: each archive is fetched once for its hash, which
                is then remembered in `MODULE.bazel.lock`. On a Bazel without facts, or for a
                module whose consumers must not fetch anything unpinned, use the JSON lock.
                """,
            allow_files = [".snapshot", ".json"],
            mandatory = True,
        ),
        "name": attr.string(
            doc = "The name of the module to create",
            mandatory = True,
        ),
    },
)

def _cpan_impl(module_ctx):
    hubs = {}
    declared_by = {}
    root_module_direct_deps = []
    root_module_direct_dev_deps = []
    for mod in module_ctx.modules:
        for attrs in mod.tags.install:
            if attrs.name in hubs:
                fail("cpan.install: hub `{}` is declared by both `{}` and `{}`.".format(
                    attrs.name,
                    declared_by[attrs.name],
                    mod.name,
                ))
            hubs[attrs.name] = attrs
            declared_by[attrs.name] = mod.name
            if mod.is_root:
                if module_ctx.is_dev_dependency(attrs):
                    root_module_direct_dev_deps.append(attrs.name)
                else:
                    root_module_direct_deps.append(attrs.name)

    # Every hub of every module is planned together, so that hubs pinning the
    # same archive share one repository of it.
    facts = getattr(module_ctx, "facts", None)
    plan = plan_hubs(module_ctx, hubs, facts)
    create_repos(plan)

    # The hashes read from snapshots are remembered in the lockfile, where a
    # Bazel has facts to remember them with.
    metadata = {}
    if facts != None:
        metadata["facts"] = plan.facts

    return module_ctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = root_module_direct_deps,
        root_module_direct_dev_deps = root_module_direct_dev_deps,
        **metadata
    )

cpan = module_extension(
    doc = """A module extension for defining Perl dependencies from [CPAN](https://www.cpan.org/).

    Each `install` tag makes a hub, `@<name>`, with a package per distribution
    of its lock: `@<name>//Capture-Tiny` is the library, and
    `@<name>//App-cloc:bin_cloc` a binary from `bins`. Each distinct archive is
    downloaded once and shared by every hub, of every module, that pins it.
    """,
    implementation = _cpan_impl,
    tag_classes = {
        "install": _install_tag,
    },
)
