#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/../.." && pwd)"
dist_dir="${1:-$repo_root/dist}"

if [[ "$dist_dir" != /* ]]; then
  dist_dir="$repo_root/$dist_dir"
fi
if [[ ! -d "$dist_dir" ]]; then
  printf 'Distribution directory does not exist: %s\n' "$dist_dir" >&2
  exit 1
fi

dist_dir="$(CDPATH= cd -- "$dist_dir" && pwd)"
assets=(
  krisis-knightmare-release.love
  krisis-knightmare-debug.love
  krisis-knightmare-release-win64.zip
  krisis-knightmare-debug-win64.zip
)

for asset in "${assets[@]}"; do
  if [[ ! -s "$dist_dir/$asset" ]]; then
    printf 'Missing or empty release asset: %s\n' "$dist_dir/$asset" >&2
    exit 1
  fi
done

if ! command -v sha256sum >/dev/null 2>&1; then
  printf 'Required command not found: sha256sum\n' >&2
  exit 1
fi

manifest="$dist_dir/SHA256SUMS"
temporary_manifest="$(mktemp "$dist_dir/.SHA256SUMS.XXXXXX")"
trap 'rm -f -- "$temporary_manifest"' EXIT

(
  cd -- "$dist_dir"
  sha256sum -- "${assets[@]}"
) > "$temporary_manifest"

line_count="$(wc -l < "$temporary_manifest")"
if [[ "$line_count" -ne "${#assets[@]}" ]]; then
  printf 'Expected %d manifest entries, got %s\n' "${#assets[@]}" "$line_count" >&2
  exit 1
fi

mv -- "$temporary_manifest" "$manifest"
trap - EXIT
printf 'Wrote %s\n' "$manifest"
