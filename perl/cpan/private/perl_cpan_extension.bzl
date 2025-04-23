"""Perl CPAN Extensions"""

load(":carton.bzl", "install")

_install_tag = tag_class(
    attrs = {
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

def _perl_cpan_impl(module_ctx):
    root_module_direct_deps = []
    for mod in module_ctx.modules:
        for attrs in mod.tags.install:
            root_module_direct_deps.append(install(
                module_ctx = module_ctx,
                attrs = attrs,
            ))

    return module_ctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = root_module_direct_deps,
        root_module_direct_dev_deps = [],
    )

def _new_perl_cpan_extension(*, doc):
    return module_extension(
        doc = doc,
        implementation = _perl_cpan_impl,
        tag_classes = {
            "install": _install_tag,
        },
    )

perl_cpan = _new_perl_cpan_extension(
    doc = "A module for defining Perl dependencies.",
)

perl_cpan_internal = _new_perl_cpan_extension(
    doc = "A module for defining rules_perl internal dependencies.",
)
