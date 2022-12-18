"""platforms.bzl defines metadata about the different relocatable-perl versions
"""

platforms = [
    struct(
        os = "darwin",
        cpu = "amd64",
        urls = ["https://github.com/skaji/relocatable-perl/releases/download/5.36.0.1/perl-darwin-amd64.tar.xz"],
        sha256 = "63bc5ee36f5394d71c50cca6cafdd333ee58f9eaa40bca63c85f9bd06f2c1fd6",
        strip_prefix = "perl-darwin-amd64",
        exec_compatible_with = [
            "@platforms//os:osx",
            "@platforms//cpu:aarch64",
        ],
    ),
    struct(
        os = "darwin",
        cpu = "arm64",
        urls = ["https://github.com/skaji/relocatable-perl/releases/download/5.36.0.1/perl-darwin-arm64.tar.xz"],
        sha256 = "285769f3c50c339fb59a3987b216ae3c5c573b95babe6875a1ef56fb178433da",
        strip_prefix = "perl-darwin-arm64",
        exec_compatible_with = [
            "@platforms//os:osx",
            "@platforms//cpu:arm64",
        ],
    ),
    struct(
        os = "linux",
        cpu = "amd64",
        urls = ["https://github.com/skaji/relocatable-perl/releases/download/5.36.0.1/perl-linux-amd64.tar.xz"],
        sha256 = "3bdffa9d7a3f97c0207314637b260ba5115b1d0829f97e3e2e301191a4d4d076",
        strip_prefix = "perl-linux-amd64",
        exec_compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
    ),
    struct(
        os = "linux",
        cpu = "arm64",
        urls = ["https://github.com/skaji/relocatable-perl/releases/download/5.36.0.1/perl-linux-arm64.tar.xz"],
        sha256 = "6fa4ece99e790ecbc2861f6ecb7b52694c01c2eeb215b4370f16a3b12d952117",
        strip_prefix = "perl-linux-arm64",
        exec_compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:arm64",
        ],
    ),
    struct(
        os = "windows",
        cpu = "x86_64",
        urls = [
            "https://mirror.bazel.build/strawberryperl.com/download/5.32.1.1/strawberry-perl-5.32.1.1-64bit.zip",
            "https://strawberryperl.com/download/5.32.1.1/strawberry-perl-5.32.1.1-64bit.zip",
        ],
        sha256 = "aeb973da474f14210d3e1a1f942dcf779e2ae7e71e4c535e6c53ebabe632cc98",
        strip_prefix = "",
        exec_compatible_with = [
            "@platforms//os:windows",
            "@platforms//cpu:x86_64",
        ],
    ),
]
