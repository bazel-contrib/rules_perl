"""Entry point for extensions used by bzlmod."""

load("@rules_perl//perl:deps.bzl", "perl_repos", "perl_rules_dev_dependencies")

def _perl_repositories(_module_ctx):
    perl_repos()

perl_repositories = module_extension(
    implementation = _perl_repositories,
)

def _perl_rules_dev_dependencies(_module_ctx):
    perl_rules_dev_dependencies()

perl_dev_repositories = module_extension(
    implementation = _perl_rules_dev_dependencies,
)
