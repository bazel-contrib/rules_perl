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

load(
    "//perl/private:perl.bzl",
    _perl_binary = "perl_binary",
    _perl_library = "perl_library",
    _perl_test = "perl_test",
)
load(
    "//perl/private:perl_xs.bzl",
    _perl_system_headers = "perl_system_headers",
    _perl_xs = "perl_xs",
)
load(
    "//perl/private:providers.bzl",
    _PerlInfo = "PerlInfo",
)

PerlInfo = _PerlInfo
perl_binary = _perl_binary
perl_library = _perl_library
perl_system_headers = _perl_system_headers
perl_test = _perl_test
perl_xs = _perl_xs

# Keep this name around for legacy support.
# buildifier: disable=name-conventions
PerlLibrary = PerlInfo
