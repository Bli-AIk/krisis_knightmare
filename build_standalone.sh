#!/usr/bin/env bash
set -euo pipefail

KRISTAL_REPO="${KRISTAL_REPO:-https://github.com/KristalTeam/Kristal}"
KRISTAL_REF="${KRISTAL_REF:-v0.10.0}"
KRISTAL_EXPECTED_VERSION="${KRISTAL_EXPECTED_VERSION:-0.10.0}"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MOD_DIR="${MOD_DIR:-$SCRIPT_DIR}"
BUILD_ROOT="${BUILD_ROOT:-$MOD_DIR/.build/standalone}"
OUTPUT_DIR="${OUTPUT_DIR:-$MOD_DIR/dist}"
CACHE_DIR="${CACHE_DIR:-$MOD_DIR/.build/cache}"
BUILD_HELPER="$SCRIPT_DIR/build_standalone.py"

KRISTAL_DIR="${KRISTAL_DIR:-${KRISTAL_ROOT:-}}"
if [ -z "$KRISTAL_DIR" ]; then
  for candidate in \
    "$MOD_DIR/../../Kristal" \
    "$MOD_DIR/../Kristal" \
    "$HOME/Projects/LuaProjects/Kristal" \
    "$HOME/Projects/Kristal" \
    "$HOME/Kristal"
  do
    if [ -f "$candidate/main.lua" ]; then
      KRISTAL_DIR="$(CDPATH= cd "$candidate" && pwd -P)"
      break
    fi
  done
fi
if [ -z "$KRISTAL_DIR" ]; then
  KRISTAL_DIR="$MOD_DIR/.build/Kristal"
fi

MOD_ID="${MOD_ID:-krisis_knightmare}"
PROJECT_TITLE="${PROJECT_TITLE:-KRISIS: KNIGHTMARE}"
OUTPUT_BASENAME="${OUTPUT_BASENAME:-krisis-knightmare}"
EXE_BASENAME="${EXE_BASENAME:-KRISIS-KNIGHTMARE}"

LOVE_VERSION="${LOVE_VERSION:-11.5}"
LOVE_ARCH="${LOVE_ARCH:-win64}"
LOVE_WINDOWS_ZIP_URL="${LOVE_WINDOWS_ZIP_URL:-https://github.com/love2d/love/releases/download/$LOVE_VERSION/love-$LOVE_VERSION-$LOVE_ARCH.zip}"

BUILD_VARIANTS="${BUILD_VARIANTS:-release debug}"
BUILD_WINDOWS_EXE="${BUILD_WINDOWS_EXE:-1}"
UPDATE_REPOS="${UPDATE_REPOS:-0}"

log() {
  printf '[build] %s\n' "$*" >&2
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

ensure_repo() {
  repo_url="$1"
  repo_dir="$2"

  if [ -d "$repo_dir/.git" ]; then
    log "Using existing repo: $repo_dir"
    if [ "$UPDATE_REPOS" = "1" ]; then
      log "Updating repo with git pull --ff-only: $repo_dir"
      git -C "$repo_dir" pull --ff-only
    fi
  elif [ -e "$repo_dir" ]; then
    printf 'Path exists but is not a git repo: %s\n' "$repo_dir" >&2
    exit 1
  else
    log "Cloning $repo_url -> $repo_dir"
    mkdir -p "$(dirname "$repo_dir")"
    git clone --depth 1 "$repo_url" "$repo_dir"
  fi
}

ensure_kristal_ref() {
  if ! git -C "$KRISTAL_DIR" rev-parse --verify --quiet "$KRISTAL_REF^{commit}" >/dev/null; then
    log "Fetching Kristal ref: $KRISTAL_REF"
    if git ls-remote --exit-code --tags "$KRISTAL_REPO" "refs/tags/$KRISTAL_REF" >/dev/null 2>&1; then
      git -C "$KRISTAL_DIR" fetch --depth 1 origin "refs/tags/$KRISTAL_REF:refs/tags/$KRISTAL_REF"
    else
      git -C "$KRISTAL_DIR" fetch --depth 1 origin "$KRISTAL_REF"
    fi
  fi

  if ! git -C "$KRISTAL_DIR" rev-parse --verify --quiet "$KRISTAL_REF^{commit}" >/dev/null; then
    printf 'Kristal ref not available after fetch: %s\n' "$KRISTAL_REF" >&2
    exit 1
  fi

  kristal_version="$(git -C "$KRISTAL_DIR" show "$KRISTAL_REF:VERSION" | tr -d '\r\n')"
  if [ -n "$KRISTAL_EXPECTED_VERSION" ] && [ "$kristal_version" != "$KRISTAL_EXPECTED_VERSION" ]; then
    printf 'Kristal ref %s has VERSION=%s, expected %s\n' \
      "$KRISTAL_REF" "$kristal_version" "$KRISTAL_EXPECTED_VERSION" >&2
    exit 1
  fi

  log "Using Kristal ref $KRISTAL_REF (VERSION=$kristal_version)"
}

export_kristal_source() {
  stage_dir="$1"

  git -C "$KRISTAL_DIR" archive --format=tar "$KRISTAL_REF" | tar -x -C "$stage_dir"
  rm -rf "$stage_dir/.github" "$stage_dir/mods" "$stage_dir/build" "$stage_dir/output"

  staged_version="$(tr -d '\r\n' < "$stage_dir/VERSION")"
  if [ -n "$KRISTAL_EXPECTED_VERSION" ] && [ "$staged_version" != "$KRISTAL_EXPECTED_VERSION" ]; then
    printf 'Staged Kristal VERSION=%s, expected %s\n' "$staged_version" "$KRISTAL_EXPECTED_VERSION" >&2
    exit 1
  fi
}

zip_dir() {
  output_file="$1"
  source_dir="$2"
  prefix="${3:-}"

  mkdir -p "$(dirname "$output_file")"
  rm -f "$output_file"

  if command -v zip >/dev/null 2>&1; then
    if [ -n "$prefix" ]; then
      parent_dir="$(dirname "$source_dir")"
      base_dir="$(basename "$source_dir")"
      (cd "$parent_dir" && zip -9 -q -r "$output_file" "$base_dir")
    else
      (cd "$source_dir" && zip -9 -q -r "$output_file" .)
    fi
  else
    python3 "$BUILD_HELPER" zip-dir "$output_file" "$source_dir" "$prefix"
  fi
}

lua_string() {
  python3 "$BUILD_HELPER" lua-string "$1"
}

patch_lua_config() {
  variant="$1"
  stage_dir="$2"
  release_mode="$3"

  if [ "$variant" = "debug" ]; then
    identity="${MOD_ID}_debug"
    title="${PROJECT_TITLE} Debug"
  else
    identity="$MOD_ID"
    title="$PROJECT_TITLE"
  fi

  python3 "$BUILD_HELPER" patch-lua-config "$stage_dir" "$MOD_ID" "$release_mode" "$identity" "$title"
}

patch_default_framerate() {
  stage_dir="$1"

  python3 "$BUILD_HELPER" patch-default-framerate "$stage_dir"
}

patch_mod_manifest() {
  mod_dir="$1"
  mod_dev="$2"
  object_editor_enabled="$3"
  manifest="$mod_dir/mod.json"

  python3 "$BUILD_HELPER" patch-mod-manifest "$manifest" "$mod_dev" "$object_editor_enabled"
}

patch_debug_external_mod_json_support() {
  stage_dir="$1"
  loadthread="$stage_dir/src/engine/loadthread.lua"

  python3 "$BUILD_HELPER" patch-debug-external-mod-json "$loadthread" "$MOD_ID"
}

patch_kristal_release_debug_input() {
  stage_dir="$1"

  python3 "$BUILD_HELPER" patch-kristal-v010-release-debug-input "$stage_dir"
}

copy_overlay_if_set() {
  variant="$1"
  destination="$2"
  overlay_var="$(printf '%s_MOD_OVERLAY_DIR' "$variant" | tr '[:lower:]' '[:upper:]')"
  overlay_dir="${!overlay_var:-}"

  if [ -n "$overlay_dir" ]; then
    if [ ! -d "$overlay_dir" ]; then
      printf 'Overlay dir does not exist: %s\n' "$overlay_dir" >&2
      exit 1
    fi
    log "Applying $variant overlay: $overlay_dir"
    rsync -a "$overlay_dir"/ "$destination"/
  fi
}

prepare_stage() {
  variant="$1"

  case "$variant" in
    release)
      release_mode="true"
      mod_dev="false"
      object_editor_enabled="false"
      ;;
    debug)
      release_mode="false"
      mod_dev="true"
      object_editor_enabled="true"
      ;;
    *)
      printf 'Unknown variant: %s\n' "$variant" >&2
      exit 1
      ;;
  esac

  stage_dir="$BUILD_ROOT/$variant/source"
  staged_mod_dir="$stage_dir/mods/$MOD_ID"

  log "Preparing $variant stage: $stage_dir"
  rm -rf "$stage_dir"
  mkdir -p "$stage_dir"

  export_kristal_source "$stage_dir"

  mkdir -p "$stage_dir/mods"
  rsync -a \
    --exclude='/.git/' \
    --exclude='/.github/' \
    --exclude='/.vscode/' \
    --exclude='/.claude/' \
    --exclude='/.helix/' \
    --exclude='/.build/' \
    --exclude='/dist/' \
    --exclude='/target/' \
    --exclude='/build_standalone.sh' \
    --exclude='/build_standalone.py' \
    --exclude='/justfile' \
    --exclude='*.tiled-session' \
    "$MOD_DIR"/ "$staged_mod_dir"/

  copy_overlay_if_set "$variant" "$staged_mod_dir"
  if [ "$variant" = "release" ]; then
    rm -rf "$staged_mod_dir/libraries/object-editor"
  fi
  patch_lua_config "$variant" "$stage_dir" "$release_mode"
  patch_default_framerate "$stage_dir"
  patch_mod_manifest "$staged_mod_dir" "$mod_dev" "$object_editor_enabled"
  if [ "$variant" = "release" ]; then
    patch_kristal_release_debug_input "$stage_dir"
  fi
  if [ "$variant" = "debug" ]; then
    patch_debug_external_mod_json_support "$stage_dir"
  fi

  printf '%s\n' "$stage_dir"
}

ensure_love_windows() {
  if [ "$BUILD_WINDOWS_EXE" != "1" ]; then
    return
  fi

  need_cmd curl
  need_cmd unzip

  mkdir -p "$CACHE_DIR"
  love_zip="$CACHE_DIR/love-$LOVE_VERSION-$LOVE_ARCH.zip"
  love_dir="$CACHE_DIR/love-$LOVE_VERSION-$LOVE_ARCH"

  if [ ! -f "$love_zip" ]; then
    log "Downloading LÖVE $LOVE_VERSION $LOVE_ARCH"
    curl -L --fail -o "$love_zip" "$LOVE_WINDOWS_ZIP_URL"
  fi

  if [ ! -d "$love_dir" ]; then
    log "Extracting LÖVE $LOVE_VERSION $LOVE_ARCH"
    rm -rf "$CACHE_DIR/love-$LOVE_VERSION-$LOVE_ARCH.tmp"
    unzip -q "$love_zip" -d "$CACHE_DIR/love-$LOVE_VERSION-$LOVE_ARCH.tmp"
    extracted_dir="$(find "$CACHE_DIR/love-$LOVE_VERSION-$LOVE_ARCH.tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    if [ -z "$extracted_dir" ]; then
      printf 'Could not find extracted LÖVE directory in %s\n' "$love_zip" >&2
      exit 1
    fi
    mv "$extracted_dir" "$love_dir"
    rm -rf "$CACHE_DIR/love-$LOVE_VERSION-$LOVE_ARCH.tmp"
  fi

  if [ ! -f "$love_dir/love.exe" ] || [ ! -f "$love_dir/license.txt" ]; then
    printf 'Invalid LÖVE package: %s\n' "$love_dir" >&2
    exit 1
  fi
}

build_variant() {
  variant="$1"
  stage_dir="$(prepare_stage "$variant")"

  love_file="$OUTPUT_DIR/$OUTPUT_BASENAME-$variant.love"
  log "Creating .love archive: $love_file"
  zip_dir "$love_file" "$stage_dir"

  if [ "$BUILD_WINDOWS_EXE" = "1" ]; then
    love_dir="$CACHE_DIR/love-$LOVE_VERSION-$LOVE_ARCH"
    package_name="$OUTPUT_BASENAME-$variant-$LOVE_ARCH"
    package_dir="$OUTPUT_DIR/$package_name"
    win_zip="$OUTPUT_DIR/$package_name.zip"
    exe_name="$EXE_BASENAME-$variant.exe"

    log "Creating fused Windows executable: $package_dir/$exe_name"
    rm -rf "$package_dir"
    mkdir -p "$package_dir"
    cat "$love_dir/love.exe" "$love_file" > "$package_dir/$exe_name"
    cp "$love_dir"/*.dll "$package_dir"/
    cp "$love_dir/license.txt" "$package_dir"/
    if [ "$variant" = "debug" ]; then
      mkdir -p "$package_dir/mods/$MOD_ID"
      cp "$stage_dir/mods/$MOD_ID/mod.json" "$package_dir/mod.json"
      cp "$stage_dir/mods/$MOD_ID/mod.json" "$package_dir/mods/$MOD_ID/mod.json"
      {
        printf 'Debug mod.json override / Debug 版 mod.json 外部覆盖\n'
        printf '\n'
        printf '中文说明\n'
        printf '\n'
        printf '这个 debug 版会先读取 exe 内置的 mod.json，然后尝试读取外部覆盖文件。\n'
        printf '你可以直接编辑本目录下的 mod.json 或 mods/%s/mod.json 来覆盖内置配置。\n' "$MOD_ID"
        printf '也可以设置环境变量 KRISIS_MOD_JSON，指向另一个 mod.json 文件路径。\n'
        printf '读取日志会写到 LÖVE 存档目录的 external_mod_json.log；如果没生效，先看这个日志里实际检查了哪些路径。\n'
        printf '\n'
        printf '覆盖规则：\n'
        printf '%s\n' '- 对象会递归合并。'
        printf '%s\n' '- 数组、字符串、数字、布尔值会整体替换内置值。'
        printf '%s\n' '- id、folder、path 字段会被忽略，避免破坏 mod 加载路径。'
        printf '%s\n' '- 如果外部 mod.json 格式错误，游戏会忽略它并使用内置配置。'
        printf '\n'
        printf 'Windows 命令行示例：\n'
        printf '  set KRISIS_MOD_JSON=C:\\path\\to\\mod.json\n'
        printf '  KRISIS-KNIGHTMARE-debug.exe\n'
        printf '\n'
        printf '最小覆盖示例：\n'
        printf '{\n'
        printf '  "config": {\n'
        printf '    "kristal": {\n'
        printf '      "krisisRandomSeed": 12345,\n'
        printf '      "krisisInitialTP": 100\n'
        printf '    }\n'
        printf '  }\n'
        printf '}\n'
        printf '\n'
        printf 'English\n'
        printf '\n'
        printf 'This debug build reads the embedded mod.json first, then tries to merge an external override file.\n'
        printf 'Edit mod.json or mods/%s/mod.json next to this executable to override embedded mod.json values.\n' "$MOD_ID"
        printf 'You may also set KRISIS_MOD_JSON to an absolute or relative mod.json path.\n'
        printf 'A lookup log is written to external_mod_json.log in the LÖVE save directory.\n'
        printf 'Objects are merged recursively; arrays and scalar values replace the embedded value.\n'
        printf 'The id, folder, and path fields are intentionally ignored when overriding.\n'
      } > "$package_dir/README_DEBUG_MOD_JSON.txt"
    fi

    log "Creating Windows distribution archive: $win_zip"
    zip_dir "$win_zip" "$package_dir" "$(basename "$package_dir")"
  fi
}

main() {
  need_cmd git
  need_cmd rsync
  need_cmd tar
  need_cmd python3

  if [ ! -f "$BUILD_HELPER" ]; then
    printf 'Build helper not found: %s\n' "$BUILD_HELPER" >&2
    exit 1
  fi

  ensure_repo "$KRISTAL_REPO" "$KRISTAL_DIR"
  ensure_kristal_ref

  if [ "$BUILD_WINDOWS_EXE" = "1" ]; then
    ensure_love_windows
  fi

  if [ ! -f "$KRISTAL_DIR/main.lua" ]; then
    printf 'Kristal main.lua not found in %s\n' "$KRISTAL_DIR" >&2
    exit 1
  fi
  if [ ! -f "$MOD_DIR/mod.json" ]; then
    printf 'Mod manifest not found in %s\n' "$MOD_DIR" >&2
    exit 1
  fi

  mkdir -p "$OUTPUT_DIR"

  for variant in $BUILD_VARIANTS; do
    build_variant "$variant"
  done

  log "Done. Artifacts:"
  find "$OUTPUT_DIR" -maxdepth 1 -type f | sort
}

main "$@"
