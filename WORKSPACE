workspace(name = "rules_perl")

load("@rules_perl//perl:deps.bzl", "perl_register_toolchains", "perl_rules_dependencies",)

perl_rules_dependencies()
perl_register_toolchains()

# The following invocation of register_toolchains shouldn't be required as the toolchains should be registered in 
# perl_register_toolchains but for some reason the invocation of native.register_toolchains in perl_register_toolchains()
# doesn't seem to work unless called from a workspace other than rules_perl
register_toolchains(
    "@rules_perl//:darwin_toolchain",
    "@rules_perl//:linux_toolchain",
    "@rules_perl//:windows_toolchain"
)

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "fcgi",
    build_file = "//:examples/cpan_remote/fcgi.BUILD",
    sha256 = "8cfa4e1b14fb8d5acaa22ced672c6af68c0a8e25dc2a9697a0ed7f4a4efb34e4",
    strip_prefix = "FCGI-0.79",
    url = "https://cpan.metacpan.org/authors/id/E/ET/ETHER/FCGI-0.79.tar.gz",
)
