"""Entry point for extensions used by bzlmod."""

load("@rules_perl//perl:deps.bzl", "perl_repos")

def _perl_repositories(_module_ctx):
    perl_repos()

perl_repositories = module_extension(
    implementation = _perl_repositories,
)
