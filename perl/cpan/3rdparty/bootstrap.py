"""bootstrap"""

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path


def deserialize_cpanfile_snapshot(content):
    """Deserialize the contents of a `cpanfile.snapshot` file.

    Args:
        content (str): The text from a `cpanfile.snapshot`

    Returns:
        dict: A mapping of the snapshot data.
    """
    results = {}

    current = ""
    container_name = ""
    for line in content.splitlines():
        text = line.strip()

        if not text or text.startswith("#"):
            continue

        if container_name and line.startswith("      "):
            key, _, value = text.partition(" ")
            results[current][container_name][key] = value
            continue

        if line.startswith("    "):
            if text.startswith("pathname:"):
                _, _, pathname = text.partition(" ")
                results[current]["pathname"] = pathname
                continue
            if text.startswith("provides:"):
                container_name = "provides"
                continue

            if text.startswith("requirements:"):
                container_name = "requirements"
                continue

        if line.startswith("  "):
            current = text
            results[current] = {
                "provides": {},
                "requirements": {},
            }
            continue

    return results


METACPAN_API_ENDPOINT = "https://fastapi.metacpan.org/release"


def _get_release(author: str, distribution: str) -> dict[str, str]:
    url = f"{METACPAN_API_ENDPOINT}/{author}/{distribution}"
    try:
        resp = urllib.request.urlopen(url).read().decode()
    except urllib.error.HTTPError as ex:
        raise RuntimeError(f"Failed to fetch {url}: {ex}") from ex
    try:
        return json.loads(resp)["release"]
    except json.JSONDecodeError as ex:
        raise RuntimeError(f"Failed to parse JSON from {url}: {ex}") from ex
    except KeyError as ex:
        raise RuntimeError(
            f"Failed to find 'release' key in JSON from {url}: {ex}. Json:\n{resp}"
        ) from ex


def sanitize_name(module):
    name, _, _ = module.rpartition("-")
    return name


def main() -> None:
    snapshot_path = Path(sys.argv[1])
    snapshot = deserialize_cpanfile_snapshot(snapshot_path.read_text())

    lockfile = {}
    for module, data in snapshot.items():
        dependencies = set()
        for req in data["requirements"]:
            for mod, mod_data in snapshot.items():
                if req in mod_data["provides"]:
                    dependencies.add(sanitize_name(mod))
                    break
        author = data["pathname"].split("/")[-2]
        release = _get_release(author, module)

        if "Path-Tiny" in module or "String-ShellQuote" in module:
            from pprint import pprint

            pprint(release)

        lockfile[sanitize_name(release["name"])] = {
            "dependencies": sorted(dependencies),
            "sha256": release["checksum_sha256"],
            "strip_prefix": module,
            "url": release["download_url"],
        }

    lockfile = snapshot_path.parent / snapshot_path.name + ".lock.json"
    Path(lockfile).write_text(json.dumps(lockfile, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
