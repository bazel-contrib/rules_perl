# This template is used by perl_download to generate a build file for
# a downloaded Perl distribution.

package(default_visibility = ["//visibility:public"])

# tools contains executable files that are part of the toolchain.
filegroup(
    name = "runtime",
    srcs = glob(["**/*"]),
)
