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

"""Tests for perl rules."""

load("@bazel_tools//tools/build_rules:test_rules.bzl", "rule_test")

def _perl_library_test(package):
    rule_test(
        name = "hello_lib_rule_test",
        generates = [],
        rule = package + "/fibonacci:fibonacci",
    )

def _perl_binary_test(package):
    rule_test(
        name = "hello_world_rule_test",
        generates = select({
            "@platforms//os:windows": ["hello_world.bat"],
            "//conditions:default": ["hello_world"],
        }),
        rule = package + "/hello_world:hello_world",
    )

def _perl_test_test(package):
    """Issue rule tests for perl_test."""
    rule_test(
        name = "fibonacci_rule_test",
        generates = select({
            "@platforms//os:windows": ["fibonacci_test.bat"],
            "//conditions:default": ["fibonacci_test"],
        }),
        rule = package + "/fibonacci:fibonacci_test",
    )

def perl_rule_test(package):
    """Issue simple tests on perl rules."""
    _perl_library_test(package)
    _perl_binary_test(package)
    _perl_test_test(package)
