#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/checkpoint-lib.sh"

temporary_dir=""

cleanup() {
  if [[ -n "$temporary_dir" && -d "$temporary_dir" ]]; then
    rm -rf -- "$temporary_dir"
  fi
  release_lock
}
trap cleanup EXIT

acquire_lock || fail "Another checkpoint action is already running"
require_save_dir || fail "Expected BLUS30443DEMONSS005 save with PARAM.SFO was not found"
require_same_filesystem || fail "Save vault must be on the same filesystem as the RPCS3 save"
require_stable_tree || fail "Save is still changing; return to the Demon's Souls title screen and try again"

category="$DS_VAULT_DIR/checkpoints"
mkdir -p -- "$category"
stamp="$(date +%Y%m%d-%H%M%S-%N)"
temporary_dir="$(mktemp -d "$category/.checkpoint-$stamp.XXXXXX")"
final_dir="$category/checkpoint-$stamp"

cp -a -- "$DS_SAVE_DIR/." "$temporary_dir/" || fail "Checkpoint copy failed; no save was changed"
require_no_symlinks "$temporary_dir" || fail "Checkpoint copy contains a symlink"
write_manifest "$temporary_dir"
verify_manifest "$temporary_dir" || fail "Checkpoint verification failed; no save was changed"
mv -- "$temporary_dir" "$final_dir" || fail "Checkpoint publication failed; no save was changed"
temporary_dir=""
prune_verified_category "$category" "$DS_KEEP_PER_CATEGORY" || fail "Checkpoint saved, but retention cleanup failed"

success "Checkpoint ready — return to Demon's Souls and continue"
