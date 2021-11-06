# This template is used by perl_download to generate a build file for
# a downloaded Perl distribution.

load("@rules_perl//perl:toolchain.bzl", "perl_toolchain")
package(default_visibility = ["//visibility:public"])

# tools contains executable files that are part of the toolchain.
filegroup(
    name = "runtime",
    srcs = glob(["**/*"]),
)

# toolchain_impl gathers information about the Perl toolchain.
# See the PerlToolchain provider.
perl_toolchain(
    name = "toolchain_impl",
    runtime = [":runtime"],
)

# toolchain is a Bazel toolchain that expresses execution and target
# constraints for toolchain_impl. This target should be registered by
# calling register_toolchains in a WORKSPACE file.
toolchain(
    name = "toolchain",
    exec_compatible_with = [
        {exec_constraints},
    ],
    toolchain = ":toolchain_impl",
    toolchain_type = "@rules_perl//:toolchain_type",
)
