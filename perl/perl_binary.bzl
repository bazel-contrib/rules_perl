"""Perl rules for Bazel"""

load(
    "//perl/private:perl.bzl",
    _perl_binary = "perl_binary",
)

perl_binary = _perl_binary
