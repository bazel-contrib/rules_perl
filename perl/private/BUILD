exports_files([
    "binary_wrapper.bat.tpl",
    "binary_wrapper.sh.tpl",
    "entrypoint.pl",
])

alias(
    name = "binary_wrapper.tpl",
    actual = select({
        "@platforms//os:windows": "binary_wrapper.bat.tpl",
        "//conditions:default": "binary_wrapper.sh.tpl",
    }),
    visibility = ["//visibility:public"],
)
