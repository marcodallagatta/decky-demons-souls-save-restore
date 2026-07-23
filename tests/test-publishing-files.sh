#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$repo_root/.github/workflows/release.yml"
readme="$repo_root/README.md"

test -f "$workflow" || {
  printf 'FAIL: release workflow is missing\n' >&2
  exit 1
}

readme_text="$(tr '\n' ' ' < "$readme")"

for text in \
  'tags:' \
  'v*' \
  'pnpm install --frozen-lockfile' \
  'bash tests/test-restored-save-clean.sh' \
  'bash scripts/package.sh' \
  'bash tests/test-release-contents.sh' \
  'gh release create' \
  'release/demons-souls-checkpoints.zip'; do
  rg -F "$text" "$workflow" >/dev/null || {
    printf 'FAIL: release workflow is missing %s\n' "$text" >&2
    exit 1
  }
done

for text in \
  '## Legal and copyright' \
  'does not include any game files' \
  'lawfully dumped' \
  'not affiliated with or endorsed by Sony' \
  'does not include PlayStation 3 firmware, keys'; do
  printf '%s' "$readme_text" | rg -F "$text" >/dev/null || {
    printf 'FAIL: README is missing legal notice text: %s\n' "$text" >&2
    exit 1
  }
done

printf 'PASS: release workflow and legal notice are present\n'
