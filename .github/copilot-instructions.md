# Copilot Instructions for rules_perl

## Code Review Checklist

### Version Bump Requirements

When reviewing pull requests, check if changes warrant a version bump:

**ALWAYS check for version consistency:**
- Verify that `version.bzl` and `MODULE.bazel` have matching version numbers
- If they differ, flag as a critical issue

**Changes that REQUIRE a version bump:**
- New features or functionality
- Bug fixes
- Breaking changes (requires major version bump)
- Changes to public APIs or toolchains
- Updates to dependencies that affect downstream users
- Changes to Perl toolchain configurations
- Modifications to CPAN handling or extensions

**Changes that may NOT require a version bump:**
- Documentation-only changes (README, comments, docs)
- Internal test changes that don't affect functionality
- CI/CD workflow updates
- Development tooling changes

**Version files to update:**
- `version.bzl` - Update the `VERSION` constant
- `MODULE.bazel` - Update the `version` field in the `module()` declaration

**Version bump guidelines:**
- MAJOR (X.0.0): Breaking changes, incompatible API changes
- MINOR (0.X.0): New features, backwards-compatible functionality
- PATCH (0.0.X): Bug fixes, backwards-compatible fixes

**If a version bump is missing:**
1. Comment on the PR requesting a version bump
2. Specify which type of bump is needed (major/minor/patch)
3. Remind to update both `version.bzl` and `MODULE.bazel`
