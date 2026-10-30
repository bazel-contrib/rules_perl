"""Bazel tools for interfacing with Carton.

The `cpan` extension turns each hub's lock file into two kinds of repository:

- One distribution repository per distinct archive, named after the
  distribution, its version and the start of its hash. Every hub of every
  module that pins that archive shares it, so each archive is downloaded and
  extracted once. It holds the sources as a `perl_library` with no
  dependencies, since those are each hub's to decide, plus one library per hub
  with the dependencies that hub resolved, as labels back into the hub.
- One hub repository per `install` tag. It holds no files: a package per
  distribution whose `@<hub>//<distribution>` alias points at the hub's
  library in the distribution repository, and the deprecated aliases in its
  root package.
"""

# Where the archive named by a snapshot entry's `pathname` is.
_CPAN_AUTHORS_URL = "https://cpan.metacpan.org/authors/id/"

def _sanitize_bin(bin):
    """The target name of a `bins` entry: `bin/cloc` becomes `bin_cloc`."""
    return bin.replace("/", "_").replace(":", "")

def parse_snapshot(content):
    """The distributions of a `cpanfile.snapshot`, as Carton writes it.

    Args:
        content (str): The text of the snapshot.

    Returns:
        dict: Keyed by distribution directory (`Capture-Tiny-0.50`), each a dict with
            the `pathname` of the archive under a CPAN mirror's `authors/id/`, the
            modules it `provides` and the modules it has as `requirements`, both
            mapping module name to version.
    """
    distributions = {}
    current = None
    section = None
    for line in content.splitlines():
        text = line.strip()
        if not text or text.startswith("#"):
            continue
        if line.startswith("      ") and current != None and section != None:
            module, _, version = text.partition(" ")
            distributions[current][section][module] = version.strip()
        elif line.startswith("    ") and current != None:
            if text.startswith("pathname:"):
                distributions[current]["pathname"] = text[len("pathname:"):].strip()
            elif text == "provides:":
                section = "provides"
            elif text == "requirements:":
                section = "requirements"
        elif line.startswith("  "):
            current = text
            section = None
            distributions[current] = {"pathname": "", "provides": {}, "requirements": {}}

        # `DISTRIBUTIONS` and anything else in the first column is a heading.
    return distributions

def _distribution_name(key):
    """`Capture-Tiny-0.50` is the distribution `Capture-Tiny`: the key before its last `-`."""
    name, sep, _ = key.rpartition("-")
    return name if sep else key

def lock_from_snapshot(snapshot):
    """A lock in the form of the JSON lock, from a parsed snapshot, without hashes.

    The URL is the archive's place under the CPAN mirror, the directory to strip
    is the snapshot's key, and a dependency is any requirement that another
    distribution of the snapshot provides; the rest are core modules. The hash
    is the one thing a snapshot does not have, so each entry carries its
    `pathname` for the caller to look it up by.

    Args:
        snapshot (dict): See `parse_snapshot`.

    Returns:
        dict: Keyed by distribution name, each with `dependencies`, `pathname`,
            `strip_prefix` and `url`.
    """
    provided_by = {}
    keys = {}
    for key, entry in snapshot.items():
        name = _distribution_name(key)
        if name in keys:
            fail("The snapshot has two distributions named `{}`: `{}` and `{}`.".format(name, keys[name], key))
        keys[name] = key
        for module in entry["provides"]:
            provided_by[module] = name

    lock = {}
    for key, entry in snapshot.items():
        name = _distribution_name(key)
        if not entry["pathname"]:
            fail("The snapshot's `{}` has no pathname.".format(key))
        dependencies = {
            provided_by[module]: None
            for module in entry["requirements"]
            if module in provided_by and provided_by[module] != name
        }
        lock[name] = {
            "dependencies": sorted(dependencies.keys()),
            "pathname": entry["pathname"],
            "strip_prefix": key,
            "url": _CPAN_AUTHORS_URL + entry["pathname"],
        }
    return lock

def _sha256_fact(pathname):
    """The key under which the hash of an archive is remembered in the lockfile's facts."""
    return "sha256:" + pathname

def _read_lock(module_ctx, hub, attrs, facts, new_facts):
    """The lock of a hub, in the JSON lock's form, from either kind of file.

    Args:
        module_ctx (module_ctx): The current module context.
        hub (str): The hub's name, for messages.
        attrs (struct): The hub's `install` tag.
        facts (dict or None): The facts of previous evaluations, or None on a Bazel
            without them.
        new_facts (dict): Where the facts this evaluation needs kept are added.

    Returns:
        dict: Keyed by distribution name, each with `dependencies`, `sha256`,
            `strip_prefix` and `url`.
    """
    lock_file = module_ctx.path(attrs.lock)
    module_ctx.watch(lock_file)
    content = module_ctx.read(lock_file)

    if attrs.lock.name.endswith(".json"):
        # An empty file is the lock before its first compilation (see the
        # README's steps): a hub with no distributions, so that the compiler
        # can be built.
        return json.decode(content) if content.strip() else {}

    if not attrs.lock.name.endswith(".snapshot"):
        fail("Hub `{}`: `{}` is neither a `cpanfile.snapshot` nor a `.json` lock.".format(hub, attrs.lock))

    if facts == None:
        fail((
            "Hub `{}`: `{}` is a cpanfile.snapshot, which has no hashes of the archives; " +
            "reading one needs a Bazel whose module extensions have facts (module_ctx.facts), " +
            "to fetch the hashes once and remember them in MODULE.bazel.lock. This Bazel has " +
            "none: use the JSON lock that cpan_compiler writes from the snapshot instead."
        ).format(hub, attrs.lock))

    lock = lock_from_snapshot(parse_snapshot(content))
    for name in sorted(lock.keys()):
        entry = lock[name]
        key = _sha256_fact(entry["pathname"])
        sha256 = facts.get(key)
        if not sha256:
            # Not seen before: fetch the archive once for its hash. The
            # repository rule's download of it is then a repository cache hit.
            module_ctx.report_progress("Fetching {} for its hash".format(entry["pathname"]))
            sha256 = module_ctx.download(
                url = entry["url"],
                output = "archives/" + entry["pathname"],
            ).sha256
        new_facts[key] = sha256
        lock[name] = {
            "dependencies": entry["dependencies"],
            "sha256": sha256,
            "strip_prefix": entry["strip_prefix"],
            "url": entry["url"],
        }
    return lock

def _label_list(labels):
    """A list of labels as buildifier formats one in an attribute at the top level."""
    if not labels:
        return "[]"
    return "[\n" + "".join(["        {},\n".format(json.encode(label)) for label in labels]) + "    ]"

def _spoke_name(distribution, strip_prefix, sha256, url):
    """The name of the repository holding one archive of a distribution.

    Two hubs pinning the same archive share it, so the name depends only on
    the archive: `DateTime_1_67_0a1b2c3d`.
    """
    version = strip_prefix
    if strip_prefix.startswith(distribution + "-"):
        version = strip_prefix[len(distribution) + 1:]
    identity = sha256[:8] if sha256 else "%x" % (hash(url) & 0xffffffff)
    name = "{}_{}_{}".format(distribution, version, identity)
    return "".join([c if c.isalnum() or c == "_" else "_" for c in name.elems()])

_DISTRIBUTION_BUILD_FILE = """\
\"\"\"Autogenerated by rules_perl.\"\"\"

load("@rules_perl//perl:perl_binary.bzl", "perl_binary")
load("@rules_perl//perl:perl_library.bzl", "perl_library")

# The sources of the distribution, shared by every hub that pins this archive.
# Its dependencies are each hub's to decide, so none are here: every hub gets a
# library below with the ones it resolved, and that is what the hub's
# `@<hub>//{name}` alias points at. Depend on the hub.
perl_library(
    name = "{name}",
    srcs = glob(
        include = ["{output}**/*"],
        exclude = [
            "BUILD",
            "WORKSPACE",
            "*.bazel",
            "{output}t/**/*",
            "{output}xt/**/*",
        ],
    ),
    includes = {includes},
    visibility = ["//visibility:public"],
)
{hub_targets}"""

_DISTRIBUTION_HUB_LIBRARY = """
# The distribution with the dependencies the `{hub}` hub resolved for it.
perl_library(
    name = "{hub}.{name}",
    includes = [],
    visibility = ["//visibility:public"],
    deps = {deps},
)
"""

_DISTRIBUTION_HUB_BINARY = """
perl_binary(
    name = "{hub}.{name}.{bin}",
    main = "{main}",
    visibility = ["//visibility:public"],
    deps = [":{hub}.{name}"],
)
"""

_HUB_PACKAGE_BUILD_FILE = """\
\"\"\"Autogenerated by rules_perl.\"\"\"

package(default_visibility = ["//visibility:public"])

alias(
    name = "{name}",
    actual = "@{spoke}//:{hub}.{name}",
)
{bins}"""

_HUB_PACKAGE_BINARY = """
alias(
    name = "{bin}",
    actual = "@{spoke}//:{hub}.{name}.{bin}",
)
"""

_HUB_BUILD_FILE = """\
\"\"\"Autogenerated by rules_perl.\"\"\"

load("@rules_perl//perl:perl_library.bzl", "perl_library")

package(default_visibility = ["//visibility:public"])

# Every distribution of the hub.
perl_library(
    name = "{hub}",
    includes = [],
    deps = {deps},
)
{deprecated}"""

_HUB_DEPRECATED_ALIAS = """
alias(
    name = "{name}",
    actual = "//{name}",
    deprecation = "Use @{hub}//{name} instead of @{hub}//:{name}.",
)
"""

_HUB_DEPRECATED_BINARY = """
alias(
    name = "{name}_{bin}",
    actual = "//{name}:{bin}",
    deprecation = "Use @{hub}//{name}:{bin} instead of @{hub}//:{name}_{bin}.",
)
"""

def _distribution_build_file(repository_ctx, output, includes):
    """The BUILD file of a distribution repository."""
    name = repository_ctx.attr.distribution
    hubs = json.decode(repository_ctx.attr.hubs)

    hub_targets = ""
    for hub in sorted(hubs.keys()):
        hub_targets += _DISTRIBUTION_HUB_LIBRARY.format(
            hub = hub,
            name = name,
            deps = _label_list([":" + name] + ["@{}//{}".format(hub, dep) for dep in hubs[hub]["deps"]]),
        )
        for bin in hubs[hub]["bins"]:
            hub_targets += _DISTRIBUTION_HUB_BINARY.format(
                hub = hub,
                name = name,
                bin = _sanitize_bin(bin),
                main = bin,
            )

    return _DISTRIBUTION_BUILD_FILE.format(
        name = name,
        output = output,
        includes = json.encode(includes),
        hub_targets = hub_targets,
    )

def _cpan_distribution_archive_impl(repository_ctx):
    results = repository_ctx.download_and_extract(
        repository_ctx.attr.urls,
        sha256 = repository_ctx.attr.sha256,
        stripPrefix = repository_ctx.attr.strip_prefix,
    )

    output = ""
    includes = []
    lib_path = repository_ctx.path("lib")
    if lib_path.exists:
        includes = ["lib"]
    else:
        # In the event a lib directory doesn't exist, the module will need to be
        # extracted to a subdirectory.
        repository_ctx.delete(repository_ctx.path("."))
        output = ""
        split = repository_ctx.attr.distribution.split("-")
        if len(split) > 1:
            output = split[0]

        repository_ctx.download_and_extract(
            repository_ctx.attr.urls,
            sha256 = results.sha256,
            stripPrefix = repository_ctx.attr.strip_prefix,
            output = output,
        )

        includes = ["."]

    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    repository_ctx.file("BUILD.bazel", _distribution_build_file(
        repository_ctx,
        output = "{}/".format(output).lstrip("/"),
        includes = includes,
    ))

    return {
        "distribution": repository_ctx.attr.distribution,
        "hubs": repository_ctx.attr.hubs,
        "name": repository_ctx.name,
        "sha256": results.sha256,
        "strip_prefix": repository_ctx.attr.strip_prefix,
        "urls": repository_ctx.attr.urls,
    }

cpan_distribution_archive = repository_rule(
    doc = """A repository rule for fetching one archive of a Perl distribution from CPAN.

    The repository is shared by every hub that pins the archive; see `hubs`.
    """,
    implementation = _cpan_distribution_archive_impl,
    attrs = {
        "distribution": attr.string(
            doc = "The name of the distribution, e.g. `Capture-Tiny`.",
            mandatory = True,
        ),
        "hubs": attr.string(
            doc = "JSON: for each hub using the archive, the `deps` (distribution names in " +
                  "that hub) and `bins` (paths to create `perl_binary` targets for) it resolved.",
            mandatory = True,
        ),
        "sha256": attr.string(
            doc = "The expected SHA-256 of the file downloaded.",
        ),
        "strip_prefix": attr.string(
            doc = "A directory prefix to strip from the extracted files.",
        ),
        "urls": attr.string_list(
            doc = "List of mirror URLs referencing the same file to download.",
            mandatory = True,
        ),
    },
)

def _cpan_hub_impl(repository_ctx):
    hub = repository_ctx.attr.hub_name
    spokes = repository_ctx.attr.modules
    bins = repository_ctx.attr.bins
    distributions = sorted(spokes.keys())

    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    # One package per distribution: `@<hub>//<distribution>`.
    for name in distributions:
        repository_ctx.file("{}/BUILD.bazel".format(name), _HUB_PACKAGE_BUILD_FILE.format(
            hub = hub,
            name = name,
            spoke = spokes[name],
            bins = "".join([
                _HUB_PACKAGE_BINARY.format(hub = hub, name = name, spoke = spokes[name], bin = _sanitize_bin(bin))
                for bin in bins.get(name, [])
            ]),
        ))

    # The root package: everything at once, and the deprecated spellings.
    deprecated = ""
    for name in distributions:
        deprecated += _HUB_DEPRECATED_ALIAS.format(hub = hub, name = name)
        for bin in bins.get(name, []):
            deprecated += _HUB_DEPRECATED_BINARY.format(hub = hub, name = name, bin = _sanitize_bin(bin))

    repository_ctx.file("BUILD.bazel", _HUB_BUILD_FILE.format(
        hub = hub,
        deps = _label_list(["//" + name for name in distributions]),
        deprecated = deprecated,
    ))

cpan_hub = repository_rule(
    doc = "A hub repository that exposes all CPAN dependencies from a `cpanfile`.",
    implementation = _cpan_hub_impl,
    attrs = {
        "bins": attr.string_list_dict(
            doc = """
                Perl binary targets. Keys are packages, values are lists of bin paths.

                Example:

                    bins = {"App-cloc": ["bin/cloc"]},
                """,
            default = {},
        ),
        "hub_name": attr.string(
            doc = "The name of the hub.",
            mandatory = True,
        ),
        "modules": attr.string_dict(
            doc = "The distributions of the hub, and the repository holding each one's archive.",
            mandatory = True,
        ),
    },
)

def plan_hubs(module_ctx, hubs, facts = None):
    """Plan the repositories of a set of hubs.

    Args:
        module_ctx (module_ctx): The current module context.
        hubs (dict[str, struct]): The attributes of the `install` tag of each hub, keyed
            by hub name.
        facts (dict or None): `module_ctx.facts`, the facts of previous evaluations, or
            None on a Bazel without them.

    Returns:
        struct: With `spokes`, the attributes of every `cpan_distribution_archive` keyed
            by repository name, `hubs`, the attributes of every `cpan_hub`, and `facts`,
            what this evaluation needs remembered: the hash of every archive a
            snapshot names.
    """
    spokes = {}
    planned = {}
    new_facts = {}

    for hub in sorted(hubs.keys()):
        attrs = hubs[hub]
        lockfile = _read_lock(module_ctx, hub, attrs, facts, new_facts)

        modules = {}
        for distribution in sorted(lockfile.keys()):
            entry = lockfile[distribution]
            deps = sorted({dep: None for dep in entry["dependencies"] + attrs.add_deps.get(distribution, [])}.keys())
            for dep in deps:
                if dep not in lockfile:
                    fail("Hub `{}`: `{}` depends on `{}`, which is not in {}.".format(
                        hub,
                        distribution,
                        dep,
                        attrs.lock,
                    ))

            name = _spoke_name(distribution, entry["strip_prefix"], entry["sha256"], entry["url"])
            spoke = spokes.setdefault(name, {
                "distribution": distribution,
                "hubs": {},
                "sha256": entry["sha256"],
                "strip_prefix": entry["strip_prefix"],
                "urls": [],
            })
            for key, value in (
                ("distribution", distribution),
                ("sha256", entry["sha256"]),
                ("strip_prefix", entry["strip_prefix"]),
            ):
                if spoke[key] != value:
                    fail("Hub `{}` pins `{}` as repository `{}` with a different {} than hub(s) {} ({} != {}).".format(
                        hub,
                        distribution,
                        name,
                        key,
                        sorted(spoke["hubs"].keys()),
                        value,
                        spoke[key],
                    ))

            # The same bytes, possibly from different places.
            if entry["url"] not in spoke["urls"]:
                spoke["urls"].append(entry["url"])

            spoke["hubs"][hub] = {
                "bins": attrs.bins.get(distribution, []),
                "deps": deps,
            }
            modules[distribution] = name

        planned[hub] = {
            "bins": attrs.bins,
            "modules": modules,
        }

    return struct(
        facts = new_facts,
        hubs = planned,
        spokes = spokes,
    )

def create_repos(plan):
    """Instantiate the repositories of a plan from `plan_hubs`.

    Args:
        plan (struct): See `plan_hubs`.
    """
    for name, attrs in plan.spokes.items():
        cpan_distribution_archive(
            name = name,
            distribution = attrs["distribution"],
            hubs = json.encode(attrs["hubs"]),
            sha256 = attrs["sha256"],
            strip_prefix = attrs["strip_prefix"],
            urls = attrs["urls"],
        )

    for name, attrs in plan.hubs.items():
        cpan_hub(
            name = name,
            bins = attrs["bins"],
            hub_name = name,
            modules = attrs["modules"],
        )
