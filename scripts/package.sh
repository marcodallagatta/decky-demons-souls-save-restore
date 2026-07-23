#!/usr/bin/env bash
set -euo pipefail

plugin_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
release_dir="$plugin_root/release"
archive_path="$release_dir/demons-souls-checkpoints.zip"
staging_dir="$(mktemp -d)"

cleanup() {
  rm -rf -- "$staging_dir"
}
trap cleanup EXIT

cd -- "$plugin_root"
pnpm run build

mkdir -p -- "$release_dir"
rm -f -- "$archive_path"
package_dir="$staging_dir/demons-souls-checkpoints"
mkdir -p -- "$package_dir/dist"
cp -a -- bin LICENSE README.md THIRD_PARTY_NOTICES.md licenses main.py package.json plugin.json "$package_dir/"
cp -a -- dist/index.js "$package_dir/dist/"

(
  cd -- "$staging_dir"
  zip -qr "$archive_path" demons-souls-checkpoints
)

printf 'Wrote %s\n' "$archive_path"
