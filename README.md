[![Build status](https://badge.buildkite.com/2aaa805261d9267b26088e2763aa01f9ded00aaab18ed75c1e.svg)](https://buildkite.com/bazel/rules-perl-postsubmit)

# Perl Rules

The Perl Toolchain utilizes the [relocatable perl](https://github.com/skaji/relocatable-perl) project.

## Getting Started

To import rules_perl in your project, you first need to add it to your `WORKSPACE` file:


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

Once you've imported the rule set into your `WORKSPACE`, you can then load the perl rules in your `BUILD` files with:

```python
load("@rules_perl//perl:perl.bzl", "perl_binary")

perl_binary(
    name = "hello_world",
    srcs = ["hello_world.pl"]
)
```

Please see `example` folder for more examples of how to include Perl scripts.

## Mac Support

Currently, simple perl programs and Pure Perl modules work.

Modules that require compiling are not yet supported.

## Windows Support

This repository provides a hermetic [Strawberry Perl](https://strawberryperl.com/) bazel toolchain for Windows. Usage of the toolchain in `perl_xs` rules is not yet supported.

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

`perl_binary` (and `perl_test`) sets up the `PERL5LIB` environment variable with values for all `perl_library` dep's `includes`.
The default includes are `[".", "lib"]`.
