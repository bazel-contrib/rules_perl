"""Perl rules for Bazel"""

load(
    "//perl/private:perl.bzl",
    _perl_binary = "perl_binary",
    _perl_library = "perl_library",
    _perl_test = "perl_test",
)
load(
    "//perl/private:perl_xs.bzl",
    _perl_xs = "perl_xs",
)
load(
    "//perl/private:providers.bzl",
    _PerlInfo = "PerlInfo",
)

PerlInfo = _PerlInfo
perl_binary = _perl_binary
perl_library = _perl_library
perl_test = _perl_test
perl_xs = _perl_xs

# Keep this name around for legacy support.
# buildifier: disable=name-conventions
PerlLibrary = PerlInfo
