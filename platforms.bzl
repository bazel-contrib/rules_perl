"""platforms.bzl defines metadata about the different relocatable-perl versions
"""

platforms = [
    struct(
        os = "darwin",
        cpu = "arm64",
        urls = ["https://github.com/skaji/relocatable-perl/releases/download/5.38.2.0/perl-darwin-arm64.tar.xz"],
        sha256 = "1a50fe40d8d61c875546ac00e8ade1d0093e1fdc7277ab008f37e3f43c0eef82",
        strip_prefix = "perl-darwin-arm64",
        exec_compatible_with = [
            "@platforms//os:osx",
            "@platforms//cpu:aarch64",
        ],
    ),
    struct(
        os = "darwin",
        cpu = "amd64",
        urls = ["https://github.com/skaji/relocatable-perl/releases/download/5.38.2.0/perl-darwin-amd64.tar.xz"],
        sha256 = "763245980b0b2a88111460d19aee08ce707045537ed7493c34a76868f495dd53",
        strip_prefix = "perl-darwin-amd64",
        exec_compatible_with = [
            "@platforms//os:osx",
            "@platforms//cpu:x86_64",
        ],
    ),
    struct(
        os = "linux",
        cpu = "amd64",
        urls = ["https://github.com/skaji/relocatable-perl/releases/download/5.38.2.0/perl-linux-amd64.tar.xz"],
        sha256 = "0878db5752ba6ca4bed437392ceddbde05d0455f32a546f6f49f69b54a297ac2",
        strip_prefix = "perl-linux-amd64",
        exec_compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
    ),
    struct(
        os = "linux",
        cpu = "arm64",
        urls = ["https://github.com/skaji/relocatable-perl/releases/download/5.38.2.0/perl-linux-arm64.tar.xz"],
        sha256 = "d4cef73296f3b68960ad3149212df10c903676fbcbe24ad0913681bd5032cd05",
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
