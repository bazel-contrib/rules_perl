# Release Process

This document describes the process for creating a new release of rules_perl.

## Prerequisites

- Push access to the repository
- Appropriate permissions to create releases

## Release Steps

1. **Ensure all changes are merged**: Make sure all intended changes for the release are merged into the `main` branch.

2. **Create and push a tag**:
   ```bash
   git checkout main
   git pull origin main
   git tag -a 0.X.0 -m "Release 0.X.0"
   git push origin 0.X.0
   ```

3. **Create a GitHub Release**:
   - Go to https://github.com/bazel-contrib/rules_perl/releases/new
   - Select the tag you just created
   - Set the release title to match the tag (e.g., `0.X.0`)
   - Add release notes describing the changes
   - Click "Publish release"

4. **Automated Artifact Creation**:
   - The GitHub Actions workflow (`.github/workflows/release.yml`) will automatically:
     - Create a release tarball with proper structure
     - Calculate the SHA256 checksum
     - Upload the tarball and release notes to the GitHub release
   - This typically takes 1-2 minutes

5. **Verify the Release**:
   - Check that the release artifacts are attached to the GitHub release
   - Verify the SHA256 in the release notes
   - Test the release by using it in a sample project with `http_archive`

6. **Update Documentation** (if needed):
   - If this is a significant release, consider updating examples in the README to reference the new version

## Release Artifact Structure

The release tarball follows Bazel conventions:
- Named as `rules_perl-VERSION.tar.gz`
- Contains all files with a `rules_perl-VERSION/` prefix
- Users should use `strip_prefix = "rules_perl-VERSION"` in their `http_archive` declaration
- The artifact is deterministic and has a stable SHA256 checksum

## Using a Release

Users can consume releases using `http_archive` in their WORKSPACE:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_perl",
    sha256 = "SHA256_FROM_RELEASE_NOTES",
    strip_prefix = "rules_perl-0.X.0",
    urls = ["https://github.com/bazel-contrib/rules_perl/releases/download/0.X.0/rules_perl-0.X.0.tar.gz"],
)
```

## Benefits of Release Artifacts

- **Reproducible**: Fixed SHA256 checksums ensure build reproducibility
- **Cacheable**: Bazel can cache and mirror the artifacts
- **No git dependency**: Users don't need git in their build environment
- **Faster**: HTTP downloads are faster than git clones
- **Stable**: Unlike GitHub's source tarballs, our release artifacts have guaranteed stable checksums
