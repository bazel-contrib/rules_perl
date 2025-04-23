import json
import logging
from pathlib import Path
from typing import Final
import urllib.request
import urllib.error
import sys
import os

METACPAN_API_ENDPOINT: Final = "https://fastapi.metacpan.org/release"

logger = logging.getLogger(__name__)


class LockError(RuntimeError):
    """Failed to generate Lockfile."""


def _get_release(author: str, distribution: str) -> dict[str, str]:
    url = f"{METACPAN_API_ENDPOINT}/{author}/{distribution}"
    try:
        resp = urllib.request.urlopen(url).read().decode()
    except urllib.error.HTTPError as ex:
        raise LockError(f"Failed to fetch {url}: {ex}") from ex
    try:
        return json.loads(resp)["release"]
    except json.JSONDecodeError as ex:
        raise LockError(f"Failed to parse JSON from {url}: {ex}") from ex
    except KeyError as ex:
        raise LockError(
            f"Failed to find 'release' key in JSON from {url}: {ex}. Json:\n{resp}"
        ) from ex


def lock(snapshot: Path) -> dict[str, dict[str, str]]:
    lines = snapshot.read_text().splitlines()
    del lines[: lines.index("DISTRIBUTIONS") + 1]
    lockfile = {}
    distribution: str | None = None
    for line in lines:
        if not distribution and not line.startswith(" " * 3):
            distribution = line.strip()
        elif distribution and line.strip().startswith("pathname: "):
            pathname = line.strip().split(": ")[1]
            author = pathname.split("/")[-2]
            rel = _get_release(author, distribution)
            distribution = None
            logger.info(f"Adding {rel['distribution']}")
            lockfile[rel["distribution"]] = {
                "release": rel["name"],
                "url": rel["download_url"],
                "sha256": rel["checksum_sha256"],
            }
    return lockfile


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    snapshot = Path("/Users/andrebrisco/Code/rules_perl/perl/cpan/3rdparty/cpanfile.snapshot")
    if not snapshot.is_absolute():
        snapshot = Path(os.getenv("BUILD_WORKING_DIRECTORY", ".")) / snapshot
    lockfile = Path(
        sys.argv[2] if len(sys.argv) >= 3 else "cpanfile.snapshot.lock.json"
    )
    if not lockfile.is_absolute():
        lockfile = Path(os.getenv("BUILD_WORKING_DIRECTORY", ".")) / lockfile

    try:
        lock_json = lock(snapshot)
    except (LockError, FileNotFoundError) as ex:
        print(ex, file=sys.stderr)
        sys.exit(1)
    print(json.dumps(lock_json, indent=2) + "\n")
