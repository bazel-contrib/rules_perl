load("@rules_perl//perl:toolchain.bzl", "perl_toolchain", "current_perl_toolchain")


# toolchain_type defines a name for a kind of toolchain. Our toolchains
# declare that they have this type. Our rules request a toolchain of this type.
# Bazel selects a toolchain of the correct type that satisfies platform
# constraints from among registered toolchains.
toolchain_type(
    name = "toolchain_type",
    visibility = ["//visibility:public"],
)

[
    (
        # toolchain_impl gathers information about the Perl toolchain.
        # See the PerlToolchain provider.
        perl_toolchain(
            name = "{os}_toolchain_impl".format(os = os),
            runtime = ["@perl_{os}_amd64//:runtime".format(os = os)],
        ),

        # toolchain is a Bazel toolchain that expresses execution and target
        # constraints for toolchain_impl. This target should be registered by
        # calling register_toolchains in a WORKSPACE file.
        toolchain(
            name = "{os}_toolchain".format(os = os),
            exec_compatible_with = [
                "@platforms//os:{os}".format(os = os if os != "darwin" else "osx"),
                "@platforms//cpu:x86_64"
            ],
            target_compatible_with = [
                "@platforms//os:{os}".format(os = os if os != "darwin" else "osx"),
                "@platforms//cpu:x86_64"
            ],
            toolchain = "{os}_toolchain_impl".format(os = os),
            toolchain_type = ":toolchain_type",
        )
    )
    for os in ["darwin", "linux", "windows"]
]

# This rule exists so that the current perl toolchain can be used in the `toolchains` attribute of
# other rules, such as genrule. It allows exposing a perl_toolchain after toolchain resolution has
# happened, to a rule which expects a concrete implementation of a toolchain, rather than a
# toochain_type which could be resolved to that toolchain.
#
# See https://github.com/bazelbuild/bazel/issues/14009#issuecomment-921960766
current_perl_toolchain(
    name = "current_toolchain",
    visibility = ["//visibility:public"],
)
