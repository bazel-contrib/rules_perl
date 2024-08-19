workspace(name = "rules_perl")

load("@rules_perl//perl:deps.bzl", "perl_register_toolchains", "perl_rules_dependencies", "perl_rules_dev_dependencies")
load("//:platforms.bzl", "platforms")

perl_rules_dependencies()

perl_register_toolchains()

# The following invocation of register_toolchains shouldn't be required as the
# toolchains should be registered in perl_register_toolchains but for some
# reason the invocation of native.register_toolchains in
# perl_register_toolchains() doesn't seem to work unless called from a workspace
# other than rules_perl.
[
    register_toolchains(
        "@rules_perl//:perl_{os}_{cpu}_toolchain".format(
            cpu = platform.cpu,
            os = platform.os,
        ),
    )
    for platform in platforms
]

# Testing only, do not add to your WORKSPACE
perl_rules_dev_dependencies()
