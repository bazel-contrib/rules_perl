"""Entry point for extensions used by bzlmod."""

load("@rules_perl//perl:deps.bzl", "perl_repos", "perl_rules_dev_dependencies")

def _perl_repositories(module_ctx):
    perl_repos()
    return module_ctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = "all",
        root_module_direct_dev_deps = [],
    )

perl_repositories = module_extension(
    implementation = _perl_repositories,
)

def _perl_rules_dev_dependencies(module_ctx):
    perl_rules_dev_dependencies()
    return module_ctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = [],
        root_module_direct_dev_deps = "all",
    )

perl_dev_repositories = module_extension(
    implementation = _perl_rules_dev_dependencies,
)
