"""A platform transition used to exercise perl toolchain resolution for a target
platform that has no native perl toolchain."""

def _platform_transition_impl(_settings, attr):
    return {"//command_line_option:platforms": [str(attr.platform)]}

_platform_transition = transition(
    implementation = _platform_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _build_under_platform_impl(ctx):
    return [DefaultInfo(files = depset(ctx.files.target))]

build_under_platform = rule(
    doc = "Builds `target` under `platform` so its toolchain resolution is exercised.",
    implementation = _build_under_platform_impl,
    attrs = {
        "platform": attr.label(mandatory = True),
        "target": attr.label(cfg = _platform_transition, mandatory = True),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
