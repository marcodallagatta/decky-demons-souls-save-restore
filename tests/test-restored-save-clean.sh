#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="$(mktemp -d)"
trap 'rm -rf -- "$fixture_root"' EXIT

save_dir="$fixture_root/save/BLUS30443DEMONSS005"
vault_dir="$fixture_root/vault"
state_dir="$fixture_root/state"
mkdir -p "$save_dir"
printf 'PARAM' > "$save_dir/PARAM.SFO"
printf 'before-fog-gate' > "$save_dir/USR-DATA"

run_action() {
  local action="$1"
  HOME="$fixture_root/home" \
  DS_SAVE_DIR="$save_dir" \
  DS_VAULT_DIR="$vault_dir" \
  DS_STATE_DIR="$state_dir" \
  DS_SETTLE_SECONDS=0 \
  "$repo_root/bin/$action"
}

run_action create-checkpoint.sh >/dev/null
printf 'after-death' > "$save_dir/USR-DATA"
run_action restore-checkpoint.sh >/dev/null

[[ "$(<"$save_dir/USR-DATA")" == "before-fog-gate" ]] || {
  printf 'FAIL: restore did not restore checkpoint contents\n' >&2
  exit 1
}

[[ ! -e "$save_dir/manifest.sha256" ]] || {
  printf 'FAIL: restored live save retains manifest.sha256\n' >&2
  exit 1
}

printf 'PASS: restored live save contains no checkpoint manifest\n'
