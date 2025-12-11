"""Perl CPAN Extensions"""

load("//perl/cpan/private:carton.bzl", "install")

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

                Example:

                    bins = {"App-cloc": ["bin/cloc"]},
                """,
            default = {},
        ),
        "lock": attr.label(
            doc = "The Bazel generated lockfile associated with `cpanfile.snapshot`.",
            allow_files = True,
            mandatory = True,
        ),
        "name": attr.string(
            doc = "The name of the module to create",
            mandatory = True,
        ),
    },
)

def _cpan_impl(module_ctx):
    root_module_direct_deps = []
    for mod in module_ctx.modules:
        for attrs in mod.tags.install:
            hub = install(
                module_ctx = module_ctx,
                attrs = attrs,
            )
            if mod.is_root:
                root_module_direct_deps.append(hub)

    return module_ctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = root_module_direct_deps,
        root_module_direct_dev_deps = [],
    )

cpan = module_extension(
    doc = "A module for defining Perl dependencies from [CPAN](https://www.cpan.org/).",
    implementation = _cpan_impl,
    tag_classes = {
        "install": _install_tag,
    },
)
