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
            "@rules_perl//perl:perl_{os}_{cpu}_toolchain".format(
                os = platform.os,
                cpu = platform.cpu,
            ),
        )

def perl_rules_dependencies():
    """Declares external repositories that rules_perl depends on.

    This function should be loaded and called from WORKSPACE of any project
    that uses rules_perl.
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

    _maybe(
        http_archive,
        name = "rules_shell",
        sha256 = "3e114424a5c7e4fd43e0133cc6ecdfe54e45ae8affa14fadd839f29901424043",
        strip_prefix = "rules_shell-0.4.0",
        url = "https://github.com/bazelbuild/rules_shell/releases/download/v0.4.0/rules_shell-v0.4.0.tar.gz",
    )

def _maybe(rule, name, **kwargs):
    """Declares an external repository if it hasn't been declared already."""
    if name not in native.existing_rules():
        rule(name = name, **kwargs)

def perl_rules_dev_dependencies():
    """Declares external repositories that rules_perl depends on for testing.

    This function should not be loaded outside of rules_perl.
    """
    _maybe(
        http_archive,
        name = "fcgi",
        build_file = "//:examples/cpan_remote/fcgi.BUILD",
        sha256 = "8cfa4e1b14fb8d5acaa22ced672c6af68c0a8e25dc2a9697a0ed7f4a4efb34e4",
        strip_prefix = "FCGI-0.79",
        url = "https://cpan.metacpan.org/authors/id/E/ET/ETHER/FCGI-0.79.tar.gz",
    )

    # genhtml can be used to generate HTML reports from the output of the bazel
    # coverage command. It also serves as a natural test case for Perl scripts with
    # no file extension.
    _maybe(
        http_archive,
        name = "genhtml",
        build_file = "//:examples/genhtml/genhtml.BUILD",
        sha256 = "d88b0718f59815862785ac379aed56974b9edd8037567347ae70081cd4a3542a",
        strip_prefix = "lcov-1.15/bin",
        url = "https://github.com/linux-test-project/lcov/archive/refs/tags/v1.15.tar.gz",
    )
