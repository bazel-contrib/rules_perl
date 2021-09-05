[![Build status](https://badge.buildkite.com/2aaa805261d9267b26088e2763aa01f9ded00aaab18ed75c1e.svg)](https://buildkite.com/bazel/rules-perl-postsubmit)

# Perl Rules

The Perl Toolchain utilizes the [relocatable perl](https://github.com/skaji/relocatable-perl) project.

## Getting Started

To import rules_perl in your project, you first need to add it to your `WORKSPACE` file:

```python
git_repository(
    name = "rules_perl",
    remote = "https://github.com/bazelbuild/rules_perl.git",
    branch = "master",
)

load("@rules_perl//perl:deps.bzl", "perl_register_toolchains", "perl_rules_dependencies",)

perl_rules_dependencies()
perl_register_toolchains()
```

Once you've imported the rule set into your `WORKSPACE`, you can then load the perl rules in your `BUILD` files with:

```python
load("//perl:perl.bzl", "perl_binary")

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

No Windows Support yet.  Maybe something for Strawberry Perl someday.

## Using Perl Modules

This is the first stab at getting a more mature set of Perl rules for Bazel.  Currenlty it is a manual process and, hopefully, it will be a map for automation later on.

### Current Steps

* Manually download the module that you want to use.
* Add the actual files that you need to your repository.
  * Highly recommended that you place the files in the directory structure that each Perl file is unpacked into (you may need to run `perl Makefile.PL; make` to see the final paths)
  * Recommended to create a 'cpan' directory and place the files (in their required path) there.
  * Test::Mock::Simple does **NOT** follow this pattern as it is being used as a practical example - please see 'Simple Pure Perl Example' section.
* Add the new module's information to the BUILD file in the root directory of all your modules.
  * the target in the `deps` attribute
    * At this time compiled files (result of XS) will be put in the `srcs` attribute
  * the directory where the module lives in the `env` attribute for the `PERL5LIB` variable

#### Dependencies

The process needs to be repeated for any dependencies that the module needs.

Eventually, this should be an automated process.

### Simple Pure Perl Example

Downloaded and unpacked: [Test::Mock::Simple](https://metacpan.org/pod/Test::Mock::Simple)

This modules was chosen because it has no dependencies and is pure Perl.

Moved the required file to `examples/cpan/Test-Mock-Simple-0.10/lib`

**NOTE:** this location has been chosen so you can compare what is in the tar vs what as actually needed.  This is a *bad* location!  It would be better to be in `cpan/lib`.

Create a target for the module in your BUILD file (which resides in the `cpan` directory):

```
perl_library(
    name = "TestMockSimple",
    srcs = ["Test-Mock-Simple-0.10/lib/Test/Mock/Simple.pm"],
)
```

Now you can specify it as a dependency to any script that requires that module:

```
    env = {
        "PERL5LIB": "examples/cpan/Test-Mock-Simple-0.10/lib",
    },
    deps = ["//examples/cpan:TestMockSimple"],
```

**NOTE**: at this time you need to provide the directory that Perl needs to add to @INC.
