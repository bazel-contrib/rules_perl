load("@rules_perl//perl:toolchain.bzl", "current_perl_toolchain", "perl_toolchain")

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
                "@platforms//os:{os}".format(os = os),
                "@platforms//cpu:x86_64",
            ],
            toolchain = ":{os}_toolchain_impl".format(os = os),
            toolchain_type = ":toolchain_type",
        ),
    )
    for os in [
        "linux",
        "windows",
    ]
]

# "darwin" is special; the toolchain is a fat binary with both amd64 and arm64.
perl_toolchain(
    name = "darwin_toolchain_impl",
    runtime = ["@perl_darwin_2level//:runtime"],
)

toolchain(
    name = "darwin_toolchain",
    exec_compatible_with = [
        "@platforms//os:osx",
    ],
    toolchain = ":darwin_toolchain_impl",
    toolchain_type = ":toolchain_type",
)

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
