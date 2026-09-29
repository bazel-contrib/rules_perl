"""DEPRECATED: use `@rules_perl//perl:platforms.bzl`
"""

load(
    "//perl:platforms.bzl",
    "PERL_VERSION",
    "PLATFORMS",
)

unix_version = PERL_VERSION

platforms = PLATFORMS
