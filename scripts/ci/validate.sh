#!/usr/bin/env bash
# =============================================================================
# Terraform "Validate & Lint" — single source of truth for CI and local runs.
#
# Copies the repo to a temp dir, overlays the FINAL workshop solution files
# from doc/result/**, then runs:
#   init -> fmt -check -> validate -> test (offline plan, mocked providers) -> tflint
# Plan tests live in <solution>/tests/plan.tftest.hcl.
# Your working tree (state, .terraform, tfvars) is never touched.
#
# Usage:
#   scripts/ci/validate.sh                       # all solutions
#   scripts/ci/validate.sh root external_tenant  # selected solutions
#   NO_FINAL=1 scripts/ci/validate.sh            # check starter files as-is
#                                                # (CI runs both: matrix.variant)
#   IN_PLACE=1 scripts/ci/validate.sh root       # CI: run in checkout, no copy
#
# Local (Windows): run via WSL from the repo dir (verified path):
#   wsl -e bash scripts/ci/install-tools.sh   # once
#   wsl -e bash scripts/ci/validate.sh
# Git Bash may work (needs tflint on PATH) but is untested.
# Requires: terraform, tflint (scripts/ci/install-tools.sh installs both), openssl.
# =============================================================================
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"   # where install-tools.sh puts binaries

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOLUTIONS=("$@")
[ ${#SOLUTIONS[@]} -eq 0 ] && SOLUTIONS=(root external_tenant verified_id)

if [ -n "${GITHUB_ACTIONS:-}" ]; then
  group()    { echo "::group::$*"; }
  endgroup() { echo "::endgroup::"; }
  err()      { echo "::error::$*"; }
else
  group()    { printf '\n\033[1;34m=== %s\033[0m\n' "$*"; }
  endgroup() { :; }
  err()      { printf '\033[1;31mERROR: %s\033[0m\n' "$*"; }
fi

for tool in terraform tflint; do
  command -v "$tool" >/dev/null || { err "$tool not found (run scripts/ci/install-tools.sh)"; exit 2; }
done

# Reuse downloaded providers across runs/solutions (big speed-up locally).
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$HOME/.terraform.d/plugin-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

# --- Workspace ---------------------------------------------------------------
if [ -n "${IN_PLACE:-}" ]; then
  WORK="$REPO_ROOT"
else
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
  # Tracked files only — skips state, .terraform, secrets, IDE junk.
  (cd "$REPO_ROOT" && git ls-files -z --cached --others --exclude-standard \
    | tar --null -T - -cf -) | tar -xf - -C "$WORK"
fi

# Stage 16 reads cert/cert.pem via file() and it is not in git. Plan tests need
# *a* cert: generate a throwaway self-signed one (private key is discarded).
if [ ! -f "$WORK/cert/cert.pem" ]; then
  mkdir -p "$WORK/cert"
  openssl req -x509 -newkey rsa:2048 -nodes -keyout /dev/null -out "$WORK/cert/cert.pem" \
    -days 1 -subj "/CN=ci-throwaway" 2>/dev/null || { err "openssl failed to create cert/cert.pem"; exit 2; }
fi

# --- Overlay final solution --------------------------------------------------
overlay_final() {
  case "$1" in
    root)            cp "$WORK/doc/result/root/main.tf"        "$WORK/main.tf" ;;
    verified_id)     cp "$WORK/doc/result/verified_id/main.tf" "$WORK/verified_id/main.tf" ;;
    external_tenant) cp "$WORK"/doc/result/external_id/*.tf    "$WORK/external_tenant/" ;;
  esac
}

solution_path() {
  case "$1" in
    root) echo "." ;;
    external_tenant|verified_id) echo "$1" ;;
    *) err "unknown solution '$1' (root|external_tenant|verified_id)"; exit 2 ;;
  esac
}

# Dirs with .tf files that belong to a solution (root excludes the other two).
lint_dirs() {
  local p; p="$(solution_path "$1")"
  local extra=()
  [ "$1" = root ] && extra=(-not -path './doc/*' -not -path './external_tenant/*' -not -path './verified_id/*')
  [ "$p" = . ] || p="./$p"
  (cd "$WORK" && find "$p" -name '*.tf' -not -path '*/.terraform/*' "${extra[@]}" -printf '%h\n' | sort -u)
}

# --- Run ---------------------------------------------------------------------
declare -A RESULT
(cd "$WORK" && tflint --init >/dev/null) || { err "tflint --init failed"; exit 2; }

for s in "${SOLUTIONS[@]}"; do
  p="$(solution_path "$s")"
  [ -z "${NO_FINAL:-}" ] && overlay_final "$s"
  fail=0

  group "[$s] terraform init"
  ok=0
  for attempt in 1 2 3; do   # provider downloads from GitHub can time out
    (cd "$WORK/$p" && terraform init -backend=false -input=false -no-color) && { ok=1; break; }
    echo "init attempt $attempt failed, retrying..."; sleep 5
  done
  [ $ok = 1 ] || { err "[$s] init"; fail=1; }
  endgroup

  group "[$s] terraform fmt -check"
  (cd "$WORK/$p" && terraform fmt -check -recursive -diff) || { err "[$s] fmt"; fail=1; }
  endgroup

  if [ $ok = 1 ]; then   # validate is meaningless without providers
    group "[$s] terraform validate"
    (cd "$WORK/$p" && terraform validate -no-color) || { err "[$s] validate"; fail=1; }
    endgroup

    if ls "$WORK/$p"/tests/*.tftest.hcl >/dev/null 2>&1; then
      group "[$s] terraform test (offline plan, mocked providers)"
      (cd "$WORK/$p" && terraform test -no-color) || { err "[$s] test"; fail=1; }
      endgroup
    fi
  fi

  while read -r dir; do
    group "[$s] tflint $dir"
    (cd "$WORK" && tflint --chdir "$dir" --minimum-failure-severity=error) || { err "[$s] tflint $dir"; fail=1; }
    endgroup
  done < <(lint_dirs "$s")

  RESULT[$s]=$fail
done

# --- Summary -----------------------------------------------------------------
echo; echo "Summary:"; rc=0
for s in "${SOLUTIONS[@]}"; do
  if [ "${RESULT[$s]}" = 0 ]; then echo "  PASS  $s"; else echo "  FAIL  $s"; rc=1; fi
done
exit $rc
