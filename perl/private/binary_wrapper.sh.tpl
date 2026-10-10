#!/bin/sh

# --- begin runfiles.sh initialization v4 ---
# Adapted from the Bazel POSIX shell runfiles library v4: the same search, run
# for the POSIX `runfiles.sh` first. A Bazel whose `@rules_shell//shell/runfiles`
# is still the bash library bundled with Bazel (Bazel 7) has no `runfiles.sh`;
# then the launcher re-executes itself under bash and sources `runfiles.bash`.
set -u; set +e; _rf_p=; _rf_a=
if [ -n "${AWK:-}" ] || [ "${RULES_SHELL_RUNFILES_USE_AWK:-}" != 0 ]; then _rf_a=1; fi
_rf_d() { [ -f "$1/$f" ] && _rf_p="$1/$f"; }
_rf_m() { [ -f "$1" ] || return 1; if [ -n "$_rf_a" ]; then \
  _rf_p=$(${AWK:-awk} -v k="$f " 'index($0,k)==1{print substr($0,length(k)+1);m=1;exit}END{exit !m}' < "$1" 2>/dev/null); case $? in 0) return;; 1) return 1;; esac; fi; \
  while IFS= read -r _rf_l || [ -n "$_rf_l" ]; do \
  case "$_rf_l" in "$f "*) _rf_p="${_rf_l#"$f "}"; return;; esac; done < "$1"; return 1; }
_rf_f() { _rf_d "${RUNFILES_DIR:-/dev/null}" || _rf_m "${RUNFILES_MANIFEST_FILE:-/dev/null}" || \
  _rf_d "$0.runfiles" || _rf_m "$0.runfiles_manifest" || _rf_m "$0.exe.runfiles_manifest"; }
f=rules_shell/shell/runfiles/runfiles.sh
if ! _rf_f; then
  f=bazel_tools/tools/bash/runfiles/runfiles.bash
  _rf_f || { echo>&2 "ERROR: cannot find $f"; exit 1; }
  [ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"
fi
# shellcheck disable=SC1090
. "$_rf_p" || { echo>&2 "ERROR: cannot source $_rf_p"; exit 1; }; f=; unset -f _rf_d _rf_m _rf_f; unset _rf_l _rf_p _rf_a; set -e
# --- end runfiles.sh initialization v4 ---

set -eu

INTERPRETER="$(rlocation "{interpreter}")"
ENTRYPOINT="$(rlocation "{entrypoint}")"
CONFIG="$(rlocation "{config}")"
MAIN="$(rlocation "{main}")"

runfiles_export_envvars

exec \
    "${INTERPRETER}" \
    "${ENTRYPOINT}" \
    "${CONFIG}" \
    "${MAIN}" \
    -- \
    "$@"
