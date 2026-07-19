#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/../.." && pwd)"
mod_dir="${MOD_DIR:-$repo_root}"
build_dir="${MOD_BUILD_DIR:-$repo_root/.build/mod}"
output_dir="${OUTPUT_DIR:-$repo_root/dist}"
output_file="${MOD_OUTPUT_FILE:-$output_dir/krisis-knightmare-mod.zip}"
manifest="$mod_dir/mod.json"
stage_dir="$build_dir/source"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

need_cmd python3
need_cmd rsync
need_cmd unzip
need_cmd zip

if [[ ! -f "$manifest" ]]; then
  printf 'Mod manifest not found: %s\n' "$manifest" >&2
  exit 1
fi

rm -rf "$stage_dir"
mkdir -p "$stage_dir" "$output_dir"

# Keep the archive installable as a Kristal project while excluding repository,
# editor, debug, and build-only files from the player download.
rsync -a \
  --exclude='/.git/' \
  --exclude='/.github/' \
  --exclude='/.vscode/' \
  --exclude='/.claude/' \
  --exclude='/.emacs/' \
  --exclude='/.helix/' \
  --exclude='/.build/' \
  --exclude='/.worktree/' \
  --exclude='/dist/' \
  --exclude='/debug/' \
  --exclude='/target/' \
  --exclude='/build_standalone.sh' \
  --exclude='/build_standalone.py' \
  --exclude='/justfile' \
  --exclude='/release-please-config.json' \
  --exclude='/.release-please-manifest.json' \
  --exclude='/.gitmodules' \
  --exclude='/.gitignore' \
  --exclude='__pycache__/' \
  --exclude='*.pyc' \
  --exclude='*.tiled-project' \
  --exclude='*.tiled-session' \
  "$mod_dir"/ "$stage_dir"/

# Apply the same player-facing manifest settings used by the standalone
# release, but only to the temporary mod package staging directory.
python3 "$repo_root/build_standalone.py" patch-mod-manifest \
  "$stage_dir/mod.json" false false
rm -rf "$stage_dir/libraries/object-editor"

rm -f "$output_file"
(cd "$stage_dir" && zip -9 -q -r "$output_file" .)

test -s "$output_file"
unzip -t "$output_file" >/dev/null
if ! unzip -Z1 "$output_file" | grep -Fx 'mod.json' >/dev/null; then
  printf 'mod.json is not at the archive root: %s\n' "$output_file" >&2
  exit 1
fi

printf 'Created mod package: %s\n' "$output_file"
