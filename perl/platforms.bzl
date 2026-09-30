"""platforms.bzl defines metadata about the different relocatable-perl versions
"""

UNIX_VERSION = "5.40.1.0"

PLATFORMS = [
    struct(
        os = "darwin",
        cpu = "arm64",
        urls = ["https://github.com/skaji/relocatable-perl/releases/download/{}/perl-darwin-arm64.tar.xz".format(UNIX_VERSION)],
        sha256 = "e58b98338bc52f352dc95310363ab6c725897557512b90b593c70ea357f1b2ab",
        strip_prefix = "perl-darwin-arm64",
        target_compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:aarch64",
        ],
    ),
    struct(
        os = "darwin",
        cpu = "amd64",
        urls = ["https://github.com/skaji/relocatable-perl/releases/download/{}/perl-darwin-amd64.tar.xz".format(UNIX_VERSION)],
        sha256 = "6e16d12f6a765cbb708ebcb6fe9c74f0d71e1d648bff0ff7b8d88134e54b736a",
        strip_prefix = "perl-darwin-amd64",
        target_compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:x86_64",
        ],
    ),
    struct(
        os = "linux",
        cpu = "amd64",
        urls = ["https://github.com/skaji/relocatable-perl/releases/download/{}/perl-linux-amd64.tar.xz".format(UNIX_VERSION)],
        sha256 = "cd3216bd72fa4fe3b76fc7f4e2f1004d75e42495d515c09b53d79cba3700dd7b",
        strip_prefix = "perl-linux-amd64",
        target_compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
    ),
    struct(
        os = "linux",
        cpu = "arm64",
        urls = ["https://github.com/skaji/relocatable-perl/releases/download/{}/perl-linux-arm64.tar.xz".format(UNIX_VERSION)],
        sha256 = "01b3beb5e5f806a5447e42246b440e54a96c314284a68be89ff2b980ba4a4ec1",
        strip_prefix = "perl-linux-arm64",
        target_compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:arm64",
        ],
    ),
    struct(
        os = "windows",
        cpu = "x86_64",
        urls = [
            "https://github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/SP_54001_64bit_UCRT/strawberry-perl-5.40.0.1-64bit-portable.zip",
            "https://mirror.bazel.build/github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/SP_54001_64bit_UCRT/strawberry-perl-5.40.0.1-64bit-portable.zip",
        ],
        sha256 = "754f3e2a8e473dc68d1540c7802fb166a025f35ef18960c4564a31f8b5933907",
        strip_prefix = "",
        target_compatible_with = [
            "@platforms//os:windows",
            "@platforms//cpu:x86_64",
        ],
    ),

    # Strawberry Perl has no native Windows arm64 build yet:
    # https://github.com/StrawberryPerl/Perl-Dist-Strawberry/issues/218.
    #
    # As a stopgap (see https://github.com/bazel-contrib/rules_perl/issues/116),
    # this entry reuses the x86_64 Strawberry Perl archive above but declares
    # itself compatible with windows/arm64, relying on Windows on Arm's x86_64
    # emulation to run it. Perl is a plain interpreter with no CPU-specific
    # codegen, so it runs fine under that emulation layer -- PROVIDED the
    # emulation is actually available:
    #   - Requires Windows 11 on Arm or later. Windows 10 on Arm only emulates
    #     32-bit x86, not x64, so perl.exe will fail to launch there.
    #   - Enterprise-managed devices can disable x64 emulation via the
    #     "Turn off x64 emulation on Arm" policy (MDM/group policy). If perl
    #     fails to run despite this toolchain resolving, check that policy.
    # Drop this entry (or point it at a native archive) once Strawberry Perl
    # ships an arm64 build.
    struct(
        os = "windows",
        cpu = "arm64",
        urls = [
            "https://github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/SP_54001_64bit_UCRT/strawberry-perl-5.40.0.1-64bit-portable.zip",
            "https://mirror.bazel.build/github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/SP_54001_64bit_UCRT/strawberry-perl-5.40.0.1-64bit-portable.zip",
        ],
        sha256 = "754f3e2a8e473dc68d1540c7802fb166a025f35ef18960c4564a31f8b5933907",
        strip_prefix = "",
        target_compatible_with = [
            "@platforms//os:windows",
            "@platforms//cpu:arm64",
        ],
    ),
]
