"""The prebuilt Perl distributions the toolchains download."""

load(
    "//perl/private:perl_version.bzl",
    _PERL_BUILD = "PERL_BUILD",
    _PERL_INTEGRITY = "PERL_INTEGRITY",
    _PERL_RELEASES_URL = "PERL_RELEASES_URL",
    _PERL_VERSION = "PERL_VERSION",
)

PERL_BUILD = _PERL_BUILD
PERL_VERSION = _PERL_VERSION

# Legacy support
UNIX_VERSION = _PERL_VERSION

def _distribution(name, distribution, urls, integrity, strip_prefix, target_compatible_with, legacy_name = None):
    """One prebuilt Perl. Defines the schema every entry in PLATFORMS follows."""
    return struct(
        name = name,
        distribution = distribution,
        urls = urls,
        integrity = integrity,
        strip_prefix = strip_prefix,
        target_compatible_with = target_compatible_with,
        legacy_name = legacy_name,
    )

def _perl(platform, legacy_name = None):
    """Upstream Perl for one release platform triple, from the pinned build.

    The triple's first two components are `@platforms` CPU and OS names, so the
    constraints are derived from it.
    """
    if _PERL_BUILD and platform not in _PERL_INTEGRITY:
        fail("perl/private/perl_version.bzl pins build {} but has no integrity for {}".format(_PERL_BUILD, platform))
    cpu, os = platform.split("-")[:2]
    archive = "perl-{}-{}".format(_PERL_VERSION, platform)
    return _distribution(
        name = platform.replace("-", "_"),
        distribution = "perl",
        urls = ["{}/{}/{}.tar.xz".format(_PERL_RELEASES_URL, _PERL_BUILD, archive)],
        integrity = _PERL_INTEGRITY.get(platform, ""),
        strip_prefix = archive,
        target_compatible_with = ["@platforms//os:" + os, "@platforms//cpu:" + cpu],
        legacy_name = legacy_name,
    )

PLATFORMS = [
    # Linux, glibc >= 2.17, dynamically linked. The default.
    # TODO(platforms_contrib): constrain on
    # @platforms_contrib//os/linux/libc/glibc:at_least_2.17_available.
    _perl("x86_64-linux-gnu", legacy_name = "linux_amd64"),
    _perl("aarch64-linux-gnu", legacy_name = "linux_arm64"),

    # Linux, musl, dynamically linked.
    # TODO(platforms_contrib): constrain on @platforms_contrib//os/linux/libc/musl:available.
    _perl("x86_64-linux-musl"),
    _perl("aarch64-linux-musl"),

    # Linux, fully static: runs on any Linux regardless of libc, cannot dlopen
    # XS built after it (perl_xs refuses it; see usedl in repo.bzl).
    # TODO(platforms_contrib): needs a constraint expressing a preference for
    # static linkage; none exists yet.
    _perl("x86_64-linux-musl-static"),
    _perl("aarch64-linux-musl-static"),

    # macOS.
    _perl("x86_64-macos", legacy_name = "darwin_amd64"),
    _perl("aarch64-macos", legacy_name = "darwin_arm64"),

    # Windows, built with Visual C++. The default, and the only build on ARM64.
    _perl("x86_64-windows-msvc", legacy_name = "windows_x86_64"),
    _perl("aarch64-windows-msvc"),

    # Windows, built with mingw-w64 GCC on the UCRT (Strawberry's ABI).
    # TODO(platforms_contrib): needs a constraint for the C runtime ABI; none
    # exists yet.
    _perl("x86_64-windows-gnu"),

    # Strawberry Perl, --//perl/settings:distribution=strawberry.
    _distribution(
        name = "x86_64_windows_strawberry",
        distribution = "strawberry",
        urls = [
            "https://github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/SP_54001_64bit_UCRT/strawberry-perl-5.40.0.1-64bit-portable.zip",
            "https://mirror.bazel.build/github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/SP_54001_64bit_UCRT/strawberry-perl-5.40.0.1-64bit-portable.zip",
        ],
        integrity = "sha256-dU8+Ko5HPcaNFUDHgC+xZqAl817xiWDEVkox+LWTOQc=",
        strip_prefix = "",
        target_compatible_with = ["@platforms//os:windows", "@platforms//cpu:x86_64"],
    ),
]

# The vendors present in PLATFORMS; the values of --//perl/settings:distribution.
DISTRIBUTIONS = sorted({p.distribution: None for p in PLATFORMS}.keys())

def perl_toolchain_labels(kind):
    """Labels of every toolchain of one kind, in registration order.

    Args:
        kind: `toolchain`, `toolchain_exec` or `toolchain_any_target`.

    Returns:
        A list of labels under `@rules_perl//perl`.
    """
    return ["@rules_perl//perl:perl_{}_{}".format(p.name, kind) for p in PLATFORMS]
