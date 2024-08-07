# Copyright 2021 The Bazel Authors. All rights reserved.
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

load("@rules_perl//perl:perl.bzl", "perl_library", "perl_xs")

perl_library(
    name = "FCGI",
    srcs = [
        "lib/FCGI.pm",
        ":FCGIXS",
    ],
    includes = [
        "arch",
        "lib",
    ],
    visibility = ["//visibility:public"],
)

genrule(
    name = "install",
    srcs = ["FCGI.pm"],
    outs = ["lib/FCGI.pm"],
    cmd = "cp $< $@",
)

perl_xs(
    name = "FCGIXS",
    srcs = ["FCGI.xs"],
    cc_srcs = [
        "fcgiapp.c",
        "os_unix.c",
    ],
    defines = [
        "HAVE_LIMITS_H",
        "HAVE_NETDB_H",
        "HAVE_NETINET_IN_H",
        "HAVE_SYS_SOCKET_H",
        "HAVE_SYS_TIME_H",
        "HAVE_SYS_TYPES_H",
        "HAVE_UNISTD_H",
        "VERSION=\"0.79\"",
        "XS_VERSION=\"0.79\"",
    ],
    output_loc = "arch/auto/FCGI/FCGI.so",
    textual_hdrs = [
        "fastcgi.h",
        "fcgi_config.h",
        "fcgiapp.h",
        "fcgimisc.h",
        "fcgios.h",
    ],
    typemaps = ["typemap"],
)

genrule(
    name = "empty",
    outs = ["fcgi_config.h"],
    cmd = "touch $@",
)
