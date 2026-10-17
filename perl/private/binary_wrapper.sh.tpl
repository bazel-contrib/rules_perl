#!/bin/sh

# --- begin runfiles.sh initialization v1 ---
# Copy-pasted from the Bazel POSIX shell runfiles library v1.
set +e; f=shell/runfiles/runfiles.sh; _rf_p=
_rf_d() { [ -f "$1/$f" ] && _rf_p="$1/$f"; }
_rf_m() { [ -f "$1" ] || return 1; while IFS= read -r _rf_l || [ -n "$_rf_l" ]; do \
  case "$_rf_l" in "$f "*) _rf_p="${_rf_l#"$f "}"; return;; esac; done < "$1"; return 1; }
_rf_d "${RUNFILES_DIR:-/dev/null}" || _rf_m "${RUNFILES_MANIFEST_FILE:-/dev/null}" || \
  _rf_d "$0.runfiles" || _rf_m "$0.runfiles_manifest" || _rf_m "$0.exe.runfiles_manifest" || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }
# shellcheck disable=SC1090
. "$_rf_p"; f=; unset -f _rf_d _rf_m; unset _rf_l _rf_p; set -e
# --- end runfiles.sh initialization v1 ---

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
