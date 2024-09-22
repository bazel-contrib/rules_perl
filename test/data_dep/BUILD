genrule(
    name = "gen_program_sh",
    srcs = ["@genhtml//:genhtml_bin"],
    outs = ["program.sh"],
    cmd = """\
cat <<"EOF" >$@
#!/bin/bash
set -euxo pipefail
genhtml='$(rootpath @genhtml//:genhtml_bin)'
test "$$("$$genhtml" --version)" == "genhtml: LCOV version 1.0"
EOF
""",
)

sh_binary(
    name = "program_bin",
    srcs = ["program.sh"],
    data = ["@genhtml//:genhtml_bin"],
)

genrule(
    name = "gen_program_test_sh",
    srcs = [":program_bin"],
    outs = ["program_test.sh"],
    cmd = """\
echo '#!/bin/sh' >$@
echo 'exec env --ignore-environment test/data_dep/program_bin' >>$@
""",
)

# sh_test(
#     name = "program_test",
#     srcs = ["program_test.sh"],
#     data = [":program_bin"],
# )
