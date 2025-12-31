[![Build status](https://badge.buildkite.com/2aaa805261d9267b26088e2763aa01f9ded00aaab18ed75c1e.svg)](https://buildkite.com/bazel/rules-perl-postsubmit)

# Perl Rules

The Perl Toolchain utilizes the [relocatable perl](https://github.com/skaji/relocatable-perl) project.

## Getting Started

To import rules_perl in your project, you first need to add it to your `MODULE.bazel` file (or `WORKSPACE` if still using legacy mode):

### Using Bzlmod (Recommended)

Add to your `MODULE.bazel`:

```python
bazel_dep(name = "rules_perl", version = "0.1.0")  # Use appropriate version

# Register toolchains
perl = use_extension("@rules_perl//perl:extensions.bzl", "perl")
perl.toolchain()
use_repo(perl, "perl")
```

### Using WORKSPACE (Legacy)

If you are still using `WORKSPACE` to manage your dependencies:

```python
git_repository(
    name = "rules_perl",
    remote = "https://github.com/bazelbuild/rules_perl.git",
    branch = "main",
)

load("@rules_perl//perl:deps.bzl", "perl_register_toolchains", "perl_rules_dependencies")

perl_rules_dependencies()
perl_register_toolchains()
```

### Basic Usage

Once you've imported the rule set, you can load the perl rules in your `BUILD` files:

```python
load("@rules_perl//perl:perl.bzl", "perl_binary", "perl_library", "perl_test")

perl_binary(
    name = "hello_world",
    srcs = ["hello_world.pl"],
)

perl_test(
    name = "hello_world_test",
    srcs = ["hello_world_test.t"],
)

perl_library(
    name = "mylib",
    srcs = ["lib/MyModule.pm"],
    includes = [".", "lib"],
)
```

Please see the `examples/` folder for more examples of how to use Perl with Bazel.

## Platform Support

### Mac Support

- ✅ Simple Perl programs and scripts
- ✅ Pure Perl modules
- ⚠️ XS modules (limited support - some complex modules may not compile)

### Windows Support

This repository provides a hermetic [Strawberry Perl](https://strawberryperl.com/) Bazel toolchain for Windows.

- ✅ Simple Perl programs and scripts  
- ✅ Pure Perl modules
- ⚠️ XS modules (not yet fully supported with the toolchain)

### Linux Support

- ✅ Fully supported (simple programs, Pure Perl modules, XS modules)

## Using Perl Modules

Perl modules from [CPAN](https://www.cpan.org/) can be generated using the `cpan_compiler` rule in
conjunction with the `cpan` module extension.

### Current Steps

1. Create a `cpanfile` per the [Carton](https://metacpan.org/pod/Carton) documentation.
2. Create an empty `*.json` will need to be created for Bazel to use a lockfile (e.g. `cpanfile.snapshot.lock.json`)
3. Define a `cpan_compiler` target:

  ```python
  load("//perl/cpan:cpan_compiler.bzl", "cpan_compiler")

  cpan_compiler(
      name = "compiler",
      cpanfile = "cpanfile",
      lockfile = "cpanfile.snapshot.lock.json",
      visibility = ["//visibility:public"],
  )
  ```

4. `bazel run` the new target.
5. Define a new module in `MODULE.bazel` pointing to the Bazel `*.json` lock file:

  ```python
  cpan = use_extension("@rules_perl//perl/cpan:extensions.bzl", "cpan")
  cpan.install(
      name = "cpan",
      lock = "//perl/cpan/3rdparty:cpanfile.snapshot.lock.json",
  )
  use_repo(
      cpan,
      "cpan",
  )
  ```

### Dependencies

Once the `cpan` module extension is defined, dependencies will be available through the name given to the module.
Using the example in the steps above, dependencies can be accessed through `@cpan//...`. (e.g. `@cpan//:DateTime`).

Note that [`xs`](https://perldoc.perl.org/perlxs) dependencies are currently not supported by the `cpan` extension module.

### Simple Pure Perl Example

Downloaded and unpacked: [Test::Mock::Simple](https://metacpan.org/pod/Test::Mock::Simple)

This modules was chosen because it has no dependencies and is pure Perl.

Moved the required file to `examples/cpan/Test-Mock-Simple-0.10/lib`

**NOTE:** this location has been chosen so you can compare what is in the tar vs what as actually needed.  This is a *bad* location!  It would be better to be in `cpan/lib`.

Create a target for the module in your BUILD file (which resides in the `cpan` directory):

```python
perl_library(
    name = "TestMockSimple",
    srcs = ["Test-Mock-Simple-0.10/lib/Test/Mock/Simple.pm"],
)
```

Now you can specify it as a dependency to any script that requires that module:

```python
    env = {
        "PERL5LIB": "examples/cpan/Test-Mock-Simple-0.10/lib",
    },
    deps = ["//examples/cpan:TestMockSimple"],
```

**NOTE**: at this time you need to provide the directory that Perl needs to add to @INC.

### PERL5LIB includes

`perl_binary` (and `perl_test`) automatically sets up the `PERL5LIB` environment variable with values from all `perl_library` dependencies' `includes` attribute.
The default includes are `[".", "lib"]`.

## Available Rules

### perl_binary

Creates an executable Perl script target.

**Attributes:**

| Attribute | Type | Description | Default |
|-----------|------|-------------|---------|
| `srcs` | `label_list` | Source files (`.pl`, `.pm`, `.t`, etc.). If `main` is not specified and multiple sources exist, will fail. | Required |
| `main` | `label` | The main entry point file. If not specified, inferred from single `srcs` entry. | `None` |
| `deps` | `label_list` | Other `perl_library` targets this binary depends on. | `[]` |
| `data` | `label_list` | Files needed at runtime. | `[]` |
| `env` | `string_dict` | Environment variables to set. Supports `$(location)` and Make variable substitution. | `{}` |
| `perlopt` | `string_list` | Arguments to pass to the Perl interpreter (e.g., `["-T"]` for taint mode). | `[]` |

**Example:**

```python
perl_binary(
    name = "my_script",
    srcs = ["script.pl"],
    main = "script.pl",
    deps = ["//lib:mylib"],
    data = ["//data:config.txt"],
    env = {
        "CONFIG_PATH": "$(location //data:config.txt)",
    },
    perlopt = ["-T"],  # Enable taint mode
)
```

### perl_library

Creates a reusable Perl library target that can be depended upon by other Perl targets.

**Attributes:**

| Attribute | Type | Description | Default |
|-----------|------|-------------|---------|
| `srcs` | `label_list` | Source files (`.pl`, `.pm`, `.t`, etc.). | Required |
| `deps` | `label_list` | Other `perl_library` targets this library depends on. | `[]` |
| `data` | `label_list` | Files needed at runtime. | `[]` |
| `includes` | `string_list` | Include directories added to `PERL5LIB`. Paths are relative to the package. | `[".", "lib"]` |

**Example:**

```python
perl_library(
    name = "fibonacci",
    srcs = ["fibonacci.pm"],
    includes = [".", "lib"],
    visibility = ["//visibility:public"],
)
```

### perl_test

Creates a Perl test target. Identical to `perl_binary` but marked as a test.

**Attributes:**

Same as `perl_binary`.

**Example:**

```python
perl_test(
    name = "fibonacci_test",
    srcs = ["fibonacci_test.t"],
    deps = [":fibonacci"],
)
```

### perl_xs

Compiles Perl XS (C extension) modules into shared libraries.

**Attributes:**

| Attribute | Type | Description | Default |
|-----------|------|-------------|---------|
| `srcs` | `label_list` | XS source files (`.xs`). | Required |
| `cc_srcs` | `label_list` | Additional C/C++ source files (`.c`, `.cc`). | `[]` |
| `deps` | `label_list` | C/C++ library dependencies (must provide `CcInfo`). | `[]` |
| `textual_hdrs` | `label_list` | Header files needed for compilation. | `[]` |
| `typemaps` | `label_list` | Typemap files for XS compilation. | `[]` |
| `copts` | `string_list` | Additional C compiler options. | `[]` |
| `defines` | `string_list` | C preprocessor defines. | `[]` |
| `linkopts` | `string_list` | Additional linker options. | `[]` |
| `output_loc` | `string` | Custom output location for the `.so` file. | `"{name}.so"` |

**Example:**

```python
load("@rules_perl//perl:perl.bzl", "perl_xs")

perl_xs(
    name = "MyXS",
    srcs = ["MyXS.xs"],
    cc_srcs = ["helper.c"],
    textual_hdrs = ["helper.h"],
    typemaps = ["typemap"],
)
```

**Note:** XS support on Windows and macOS is limited. Some complex XS modules may not compile successfully.
