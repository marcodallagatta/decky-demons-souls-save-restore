#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
archive="$repo_root/release/demons-souls-checkpoints.zip"

if unzip -l "$archive" | rg -F 'dist/index.js.map' >/dev/null; then
  printf 'FAIL: release archive contains a source map\n' >&2
  exit 1
fi

for path in \
  'demons-souls-checkpoints/dist/index.js' \
  'demons-souls-checkpoints/THIRD_PARTY_NOTICES.md' \
  'demons-souls-checkpoints/licenses/LGPL-2.1.txt' \
  'demons-souls-checkpoints/licenses/MIT-react-icons.txt'; do
  unzip -l "$archive" | rg -F "$path" >/dev/null || {
    printf 'FAIL: release archive is missing %s\n' "$path" >&2
    exit 1
  }
done

printf 'PASS: release archive excludes source maps and includes notices\n'
