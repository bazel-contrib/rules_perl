load("@rules_perl//perl:toolchain.bzl", "current_perl_toolchain")

# toolchain_type defines a name for a kind of toolchain. Our toolchains
# declare that they have this type. Our rules request a toolchain of this type.
# Bazel selects a toolchain of the correct type that satisfies platform
# constraints from among registered toolchains.
toolchain_type(
    name = "toolchain_type",
    visibility = ["//visibility:public"],
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
