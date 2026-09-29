# Migrating

## 1.2

The toolchains now download upstream Perl, built from source, instead of
relocatable-perl (Unix) and Strawberry Perl (Windows), and cover eleven
platform/type combinations instead of five.

- Repository and toolchain names follow the release's platform names:
  `@perl_linux_amd64` is now `@perl_x86_64_linux_gnu`,
  `@perl_darwin_arm64` is `@perl_aarch64_macos`, `@perl_windows_x86_64` is
  `@perl_x86_64_windows_msvc`, and so on. The old `//:perl_<os>_<cpu>_toolchain`
  aliases still resolve, to the default distribution for that platform.
- Every toolchain names its distribution, and
  `--@rules_perl//perl/settings:distribution` chooses between vendors:
  `perl` (upstream Perl, the default) or `strawberry`. Strawberry Perl is no
  longer the Windows default.
- Upstream Perl also comes as `musl` and `musl-static` builds on Linux and a
  mingw-w64 build on Windows. They are registered but, until platform
  constraints for the C library exist, not reached by toolchain resolution;
  a root module can register the one it wants ahead of rules_perl's (see the
  README).
- ithreads are now enabled on every platform (previously only on Windows), so
  `%Config` is uniform across platforms.
- `perl_xs` compiles with the toolchain's own `$Config{ccflags}` and
  `$Config{cccdlflags}`, as MakeMaker does, instead of a fixed flag list. Those
  flags carry ABI-affecting defines that are not in `config.h` (the locale
  model on macOS, for example); without them an XS object fails perl's
  load-time handshake. They are read from the distribution's `Config_heavy.pl`
  when it is downloaded and exposed as `PerlRuntimeInfo.ccflags` /
  `.cccdlflags`; `PerlRuntimeInfo.supports_xs` (from `$Config{usedl}`) is false
  for a perl without dynamic loading, which `perl_xs` refuses. A distribution
  without `Config_heavy.pl` (every perl since 5.8.1 ships one, but a trimmed
  one may not) still works for pure-Perl targets; `perl_download` sets
  `supports_xs` to false rather than failing.
- The `perl_toolchain` target for each distribution now lives in that
  distribution's repository (`@perl_<os>_<cpu>//:toolchain_impl`), where its
  `%Config` is; the `//perl:perl_<os>_<cpu>_toolchain_impl` targets are gone.

## 1.0

In 1.0, `@rules_perl//perl:toolchain_type` (and `@rules_perl//perl:current_toolchain`) represent the **target** (runtime) toolchain, so that `perl_binary` and cross-compilation use the correct interpreter for the target platform.

Rules that consume toolchains for actions (e.g. custom rules that run Perl during the build) should depend on `@rules_perl//perl:exec_toolchain_type` (or `@rules_perl//perl:current_exec_toolchain`).
