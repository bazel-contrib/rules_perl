"""Perl rules dependencies"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//:platforms.bzl", "platforms")
load("//perl:repo.bzl", _perl_download = "perl_download")

perl_download = _perl_download

# buildifier: disable=unnamed-macro
def perl_repos():
    for platform in platforms:
        perl_download(
            name = "perl_%s_%s" % (platform.os, platform.cpu),
            strip_prefix = platform.strip_prefix,
            sha256 = platform.sha256,
            urls = platform.urls,
        )

# buildifier: disable=unnamed-macro
def perl_register_toolchains():
    """Register the relocatable perl toolchains."""
    perl_repos()

    for platform in platforms:
        native.register_toolchains(
            "@rules_perl//:perl_{os}_{cpu}_toolchain".format(os = platform.os, cpu = platform.cpu),
        )

def perl_rules_dependencies():
    """Declares external repositories that rules_go_simple depends on.

    This function should be loaded and called from WORKSPACE of any project
    that uses rules_go_simple.
    """

    # bazel_skylib is a set of libraries that are useful for writing
    # Bazel rules. We use it to handle quoting arguments in shell commands.
    _maybe(
        http_archive,
        name = "bazel_skylib",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
        ],
        sha256 = "97e70364e9249702246c0e9444bccdc4b847bed1eb03c5a3ece4f83dfe6abc44",
    )

def _maybe(rule, name, **kwargs):
    """Declares an external repository if it hasn't been declared already."""
    if name not in native.existing_rules():
        rule(name = name, **kwargs)
