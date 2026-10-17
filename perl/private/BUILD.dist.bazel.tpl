# This template is used by perl_download to generate a build file for
# a downloaded Perl distribution.

load("@rules_perl//perl:toolchain.bzl", "perl_toolchain")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "runtime",
    srcs = glob(
        include = ["**/*"],
        exclude = [
            "BUILD",
            "REPO",
            "*.bazel",
        ],
    ),
)

# The compile flags, loadable-object extension and import library come from
# this distribution's own %Config; see perl_download in
# @rules_perl//perl:repo.bzl. manual: reached through the toolchain() targets
# in @rules_perl//perl during resolution, never by wildcard.
perl_toolchain(
    name = "toolchain_impl",
    cc = {cc},
    cccdlflags = {cccdlflags},
    ccflags = {ccflags},
    dlext = {dlext},
    libperl = {libperl},
    runtime = [":runtime"],
    supports_xs = {supports_xs},
    tags = ["manual"],
)
