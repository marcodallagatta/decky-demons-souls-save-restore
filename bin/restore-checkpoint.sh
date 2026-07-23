#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/checkpoint-lib.sh"

stage_dir=""
preserved_dir=""
live_moved=false

cleanup() {
  if [[ -n "$stage_dir" && -d "$stage_dir" ]]; then
    rm -rf -- "$stage_dir"
  fi
  release_lock
}
trap cleanup EXIT

acquire_lock || fail "Another checkpoint action is already running"
require_save_dir || fail "Expected BLUS30443DEMONSS005 save with PARAM.SFO was not found"
require_same_filesystem || fail "Save vault must be on the same filesystem as the RPCS3 save"
require_stable_tree || fail "Save is still changing; return to the Demon's Souls title screen and try again"

checkpoint="$(newest_verified_checkpoint)" || fail "No verified checkpoint exists"
save_parent="$(dirname -- "$DS_SAVE_DIR")"
stage_dir="$(mktemp -d "$save_parent/.BLUS30443DEMONSS005-restore.XXXXXX")"

cp -a -- "$checkpoint/." "$stage_dir/" || fail "Restore staging copy failed; no save was changed"
require_no_symlinks "$stage_dir" || fail "Restore staging contains a symlink; no save was changed"
[[ -f "$stage_dir/manifest.sha256" && ! -L "$stage_dir/manifest.sha256" ]] || fail "Checkpoint manifest is missing; no save was changed"
rm -- "$stage_dir/manifest.sha256"
write_manifest "$stage_dir"
verify_manifest "$stage_dir" || fail "Restore staging verification failed; no save was changed"
# The manifest protects the staging copy only.  Do not introduce it into the
# live RPCS3 save directory when the verified checkpoint is activated.
rm -- "$stage_dir/manifest.sha256"

category="$DS_VAULT_DIR/pre-restore"
mkdir -p -- "$category"
stamp="$(date +%Y%m%d-%H%M%S-%N)"
preserved_dir="$category/pre-restore-$stamp"
write_manifest "$DS_SAVE_DIR"
mv -- "$DS_SAVE_DIR" "$preserved_dir" || fail "Could not preserve the current live save"
live_moved=true
verify_manifest "$preserved_dir" || {
  mv -- "$preserved_dir" "$DS_SAVE_DIR" || true
  live_moved=false
  fail "Could not verify the preserved live save"
}

if ! mv -- "$stage_dir" "$DS_SAVE_DIR"; then
  mv -- "$preserved_dir" "$DS_SAVE_DIR" || true
  live_moved=false
  fail "Restore activation failed; the preserved live save remains at $preserved_dir"
fi
stage_dir=""
live_moved=false
prune_verified_category "$category" "$DS_KEEP_PER_CATEGORY" || fail "Checkpoint restored, but retention cleanup failed"

success "Boss checkpoint restored — return to Demon's Souls and load your game"
