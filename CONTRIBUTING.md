Want to contribute? Great! First, read this page (including the small print at the end).

### Before you contribute

Before you start working on a larger contribution, you should get in touch
with us first. Use the issue tracker to explain your idea so we can help and
possibly guide you.

### Updating the pinned Perl

The toolchains download one build of the prebuilt Perl releases, pinned in
`perl/private/perl_version.bzl`. To move to a newer build:

```
bazel run //tools/update_perl_version -- --build YYYYMMDD
```

This fetches that build's `SHA256SUMS` and regenerates the pin. A build may
carry several Perl versions; pass `--version X.Y.Z` to choose when it does.
The target runs under the pinned toolchain itself, so if the pin is empty or
broken, run the script directly with any perl 5:
`perl tools/update_perl_version/update_perl_version.pl --build YYYYMMDD`.

### Code reviews and other contributions.
**All submissions, including submissions by project members, require review.**
Please follow the instructions in [the contributors documentation](http://bazel.io/contributing.html).

### The small print
Contributions made by corporations are covered by a different agreement than
the one above, the
[Software Grant and Corporate Contributor License Agreement](https://cla.developers.google.com/about/google-corporate).
