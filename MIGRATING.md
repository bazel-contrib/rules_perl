# Migrating

## 1.0

In 1.0, `@rules_perl//perl:toolchain_type` (and `@rules_perl//perl:current_toolchain`) represent the **target** (runtime) toolchain, so that `perl_binary` and cross-compilation use the correct interpreter for the target platform.

Rules that consume toolchains for actions (e.g. custom rules that run Perl during the build) should depend on `@rules_perl//perl:exec_toolchain_type` (or `@rules_perl//perl:current_exec_toolchain`).
