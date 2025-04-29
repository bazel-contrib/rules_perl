"""DEPRECATED: use `@rules_perl//perl:platforms.bzl`
"""

load(
    "//perl:platforms.bzl",
    "PLATFORMS",
    "UNIX_VERSION",
)

unix_version = UNIX_VERSION

platforms = PLATFORMS
