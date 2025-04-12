# Copyright 2022 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load("@rules_perl//perl:perl.bzl", "perl_test")

genrule(
    name = "generated_html",
    srcs = [
        "coverage.dat",
        "genhtml_test.t",
    ],
    outs = ["index.html"],
    cmd = "$(execpath @genhtml//:genhtml_bin) --quiet --output-directory $$(dirname $(execpath index.html)) $(execpath coverage.dat)",
    tools = [
        "@genhtml//:genhtml_bin",
    ],
)

perl_test(
    name = "genhtml_test",
    srcs = ["genhtml_test.t"],
    data = [
        ":index.html",
    ],
    env = {
        "COVERAGE_INDEX_HTML": "$(rootpath :index.html)",
    },
    visibility = ["//visibility:public"],
)
