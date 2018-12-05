# Copyright 2015 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Perl rules for Bazel"""

_perl_file_types = FileType([".pl", ".pm", ".t"])

_perl_srcs_attr = attr.label_list(allow_files = _perl_file_types)

_perl_deps_attr = attr.label_list(
    allow_files = False,
    providers = ["transitive_perl_sources"],
)

_perl_data_attr = attr.label_list(
    allow_files = True,
)

_perl_main_attr = attr.label(
    allow_single_file = _perl_file_types,
)

_perl_env_attr = attr.string_dict()

def _collect_transitive_sources(ctx):
    result = depset(order = "postorder")
    for dep in ctx.attr.deps:
        result += dep.transitive_perl_sources

    result += _perl_file_types.filter(ctx.files.srcs)
    return result

def _get_main_from_sources(ctx):
    sources = _perl_file_types.filter(ctx.files.srcs)
    if len(sources) != 1:
        fail("Cannot infer main from multiple 'srcs'. Please specify 'main' attribute.", "main")
    return sources[0]

def _perl_library_implementation(ctx):
    transitive_sources = _collect_transitive_sources(ctx)
    return struct(
        runfiles = ctx.runfiles(collect_data = True),
        transitive_perl_sources = transitive_sources,
    )

def _is_identifier(name):
    # Must be non-empty.
    if name == None or len(name) == 0:
        return False

    # Must start with alpha or '_'
    if not (name[0].isalpha() or name[0] == "_"):
        return False

    # Must consist of alnum characters or '_'s.
    for c in name:
        if not (c.isalnum() or c == "_"):
            return False
    return True

PERL_STUB_TEMPLATE = """#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Cwd qw(abs_path realpath);
use File::Basename;
use File::Spec::Functions;

sub main {{
  my @args = @ARGV;

  # Follow symlinks, looking for my module space.
  my $stub_filename = abs_path($0);

  my $module_space = '';
  while () {{
    # Found it?
    $module_space = $stub_filename . '.runfiles';

    if (-d $module_space) {{
      last;
    }}

    if (-l $stub_filename) {{
      # Absolutize
      $stub_filename = catfile(dirname($stub_filename), readlink $stub_filename);
      continue;
    }}

    if ($0 =~ /(.*\.runfiles)/.*/) {{
      $module_space = $1;
      last;
    }}

    print "Cannot find .runfiles directory for $0" and exit 1;
  }}

  print "$module_space\n";

  my $main_filename = catfile($module_space, '{workspace_name}', '{main_path}');

{environment}

  chdir catfile($module_space, '{workspace_name}');
  exec($^X, $main_filename, @args);
}}

main()
"""

def _create_stub(workspace_name, executable_name, main_path, env, env_files):
    environment = ""
    for name, value in env.items():
        if not _is_identifier(name):
            fail("%s is not a valid environment variable name." % str(name))
        environment += ("  $ENV{{{key}}} = '{value}' " +
                        "unless defined $ENV{{{key}}};\n").format(
            key = name,
            value = value.replace("'", "\\'"),
        )

    for name, value in env_files.items():
        if not _is_identifier(name):
            fail("%s is not a valid environment variable name." % str(name))
        environment += ("  $ENV{{{key}}} = realpath(catfile($module_space, " +
                        "'{workspace_name}', '{value}')) " +
                        "unless defined $ENV{{{key}}};\n").format(
            key = name,
            value = value.replace("'", "\\'"),
            workspace_name = workspace_name,
        )

    return PERL_STUB_TEMPLATE.format(
        workspace_name = workspace_name,
        executable_name = executable_name,
        environment = environment,
        main_path = main_path,
    )

def _perl_binary_implementation(ctx):
    transitive_sources = _collect_transitive_sources(ctx)

    main = ctx.file.main
    if main == None:
        main = _get_main_from_sources(ctx)

    ctx.actions.write(
        output = ctx.outputs.executable,
        content = _create_stub(
            ctx.workspace_name,
            ctx.outputs.executable.basename,
            main.path,
            ctx.attr.env,
            ctx.attr.env_files,
        ),
        is_executable = True,
    )

    return struct(
        files = depset([ctx.outputs.executable]),
        runfiles = ctx.runfiles(
            collect_data = True,
            collect_default = True,
            transitive_files = transitive_sources + [ctx.outputs.executable],
        ),
    )

def _perl_test_implementation(ctx):
    return _perl_binary_implementation(ctx)

perl_library = rule(
    attrs = {
        "srcs": _perl_srcs_attr,
        "deps": _perl_deps_attr,
        "data": _perl_data_attr,
    },
    implementation = _perl_library_implementation,
)

perl_binary = rule(
    attrs = {
        "srcs": _perl_srcs_attr,
        "deps": _perl_deps_attr,
        "data": _perl_data_attr,
        "main": _perl_main_attr,
        "env": _perl_env_attr,
        "env_files": _perl_env_attr,
    },
    executable = True,
    implementation = _perl_binary_implementation,
)

perl_test = rule(
    attrs = {
        "srcs": _perl_srcs_attr,
        "deps": _perl_deps_attr,
        "data": _perl_data_attr,
        "main": _perl_main_attr,
        "env": _perl_env_attr,
        "env_files": _perl_env_attr,
    },
    executable = True,
    test = True,
    implementation = _perl_test_implementation,
)
