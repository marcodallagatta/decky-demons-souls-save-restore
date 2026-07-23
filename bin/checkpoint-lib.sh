#!/usr/bin/env bash

DS_SAVE_DIR="${DS_SAVE_DIR:-$HOME/.var/app/net.rpcs3.RPCS3/config/rpcs3/dev_hdd0/home/00000001/savedata/BLUS30443DEMONSS005}"
DS_VAULT_DIR="${DS_VAULT_DIR:-$HOME/.local/share/rpcs3-save-vault/demons-souls-BLUS30443}"
DS_STATE_DIR="${DS_STATE_DIR:-$HOME/.local/state/demons-souls-checkpoints}"
DS_SETTLE_SECONDS="${DS_SETTLE_SECONDS:-5}"
DS_KEEP_PER_CATEGORY=10

LOCK_DIR=""

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/ }"
  printf '%s' "$value"
}

json_result() {
  local ok="$1"
  local message="$2"
  printf '{"ok":%s,"message":"%s","timestamp":"%s"}\n' \
    "$ok" "$(json_escape "$message")" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}

fail() {
  json_result false "$1"
  exit 1
}

success() {
  json_result true "$1"
  exit 0
}

release_lock() {
  if [[ -n "$LOCK_DIR" && -d "$LOCK_DIR" ]]; then
    rmdir -- "$LOCK_DIR" 2>/dev/null || true
  fi
}

acquire_lock() {
  mkdir -p -- "$DS_STATE_DIR"
  LOCK_DIR="$DS_STATE_DIR/operation.lock"
  mkdir -- "$LOCK_DIR" 2>/dev/null
}

require_no_symlinks() {
  local directory="$1"
  [[ -d "$directory" && ! -L "$directory" ]] || return 1
  ! find "$directory" -type l -print -quit | grep -q .
}

require_save_dir() {
  [[ -f "$DS_SAVE_DIR/PARAM.SFO" && ! -L "$DS_SAVE_DIR/PARAM.SFO" ]] || return 1
  require_no_symlinks "$DS_SAVE_DIR"
}

tree_snapshot() {
  local directory="$1"
  (
    cd -- "$directory"
    find . -type f -print0 | while IFS= read -r -d '' file; do
      if stat -c '%s\t%Y' -- "$file" >/dev/null 2>&1; then
        printf '%s\t' "${file#./}"
        stat -c '%s\t%Y' -- "$file"
      else
        printf '%s\t' "${file#./}"
        stat -f '%z\t%m' -- "$file"
      fi
    done | LC_ALL=C sort
  )
}

require_stable_tree() {
  local first second
  [[ "$DS_SETTLE_SECONDS" =~ ^[0-9]+$ ]] || return 1
  first="$(tree_snapshot "$DS_SAVE_DIR")"
  sleep "$DS_SETTLE_SECONDS"
  second="$(tree_snapshot "$DS_SAVE_DIR")"
  [[ "$first" == "$second" ]]
}

write_manifest() {
  local directory="$1"
  (
    cd -- "$directory"
    find . -type f ! -name manifest.sha256 -print \
      | LC_ALL=C sort \
      | while IFS= read -r file; do sha256sum "$file"; done
  ) > "$directory/manifest.sha256"
}

verify_manifest() {
  local directory="$1"
  [[ -f "$directory/manifest.sha256" && ! -L "$directory/manifest.sha256" ]] || return 1
  (
    cd -- "$directory"
    sha256sum --check --status manifest.sha256
  )
}

filesystem_device() {
  if stat -c '%d' -- "$1" >/dev/null 2>&1; then
    stat -c '%d' -- "$1"
  else
    stat -f '%d' -- "$1"
  fi
}

require_same_filesystem() {
  local save_parent vault_parent
  save_parent="$(dirname -- "$DS_SAVE_DIR")"
  vault_parent="$(dirname -- "$DS_VAULT_DIR")"
  mkdir -p -- "$vault_parent"
  [[ "$(filesystem_device "$save_parent")" == "$(filesystem_device "$vault_parent")" ]]
}

category_entries_newest_first() {
  local category="$1"
  local candidate
  for candidate in "$category"/*; do
    [[ -d "$candidate" && ! -L "$candidate" ]] || continue
    printf '%s\t%s\n' "$(basename -- "$candidate")" "$candidate"
  done | LC_ALL=C sort -r | cut -f2-
}

newest_verified_checkpoint() {
  local category="$DS_VAULT_DIR/checkpoints"
  local checkpoint
  [[ -d "$category" ]] || return 1
  checkpoint="$(category_entries_newest_first "$category" | head -n 1)"
  [[ -n "$checkpoint" && "$(dirname -- "$checkpoint")" == "$category" ]] || return 1
  require_no_symlinks "$checkpoint" && verify_manifest "$checkpoint" || return 1
  printf '%s\n' "$checkpoint"
}

prune_verified_category() {
  local category="$1"
  local keep="$2"
  local index=0
  local candidate

  [[ "$keep" =~ ^[0-9]+$ && "$keep" -gt 0 ]] || return 1
  while IFS= read -r candidate; do
    index=$((index + 1))
    (( index > keep )) || continue
    [[ "$(dirname -- "$candidate")" == "$category" ]] || return 1
    require_no_symlinks "$candidate" && verify_manifest "$candidate" || continue
    rm -rf -- "$candidate"
  done < <(category_entries_newest_first "$category")
}
