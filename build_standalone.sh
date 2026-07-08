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
    python3 - "$output_file" "$source_dir" "$prefix" <<'PY'
import os
import sys
import zipfile
from pathlib import Path

output_file = Path(sys.argv[1])
source_dir = Path(sys.argv[2])
prefix = sys.argv[3].strip("/")

with zipfile.ZipFile(output_file, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in sorted(source_dir.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(source_dir).as_posix()
        arcname = f"{prefix}/{rel}" if prefix else rel
        archive.write(path, arcname)
PY
  fi
}

lua_string() {
  python3 - "$1" <<'PY'
import sys
value = sys.argv[1]
value = value.replace("\\", "\\\\").replace('"', '\\"')
print(f'"{value}"')
PY
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

  python3 - "$stage_dir/src/engine/vendcust.lua" "$MOD_ID" "$release_mode" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
mod_id = sys.argv[2].replace("\\", "\\\\").replace('"', '\\"')
release_mode = sys.argv[3]
text = path.read_text()
replacements = {
    r"(?m)^TARGET_MOD\s*=.*$": f'TARGET_MOD = "{mod_id}"',
    r"(?m)^AUTO_MOD_START\s*=.*$": "AUTO_MOD_START = true",
    r"(?m)^RELEASE_MODE\s*=.*$": f"RELEASE_MODE = {release_mode}",
}
for pattern, replacement in replacements.items():
    text, count = re.subn(pattern, replacement, text, count=1)
    if count != 1:
        raise SystemExit(f"Could not patch {pattern} in {path}")
path.write_text(text)
PY

  python3 - "$stage_dir/conf.lua" "$(lua_string "$identity")" "$(lua_string "$title")" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
identity = sys.argv[2]
title = sys.argv[3]
text = path.read_text()
replacements = {
    r"(?m)^(\s*t\.identity\s*=\s*).*$": rf"\g<1>{identity}",
    r"(?m)^(\s*t\.window\.title\s*=\s*).*$": rf"\g<1>{title}",
}
for pattern, replacement in replacements.items():
    text, count = re.subn(pattern, replacement, text, count=1)
    if count != 1:
        raise SystemExit(f"Could not patch {pattern} in {path}")
path.write_text(text)
PY
}

patch_mod_manifest() {
  mod_dir="$1"
  mod_dev="$2"
  manifest="$mod_dir/mod.json"

  python3 - "$manifest" "$mod_dev" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
mod_dev = sys.argv[2]
text = path.read_text()
text, count = re.subn(r'("dev"\s*:\s*)(true|false)', rf"\g<1>{mod_dev}", text, count=1)
if count != 1:
    raise SystemExit(f'Could not patch "dev" in {path}')
path.write_text(text)
PY
}

patch_debug_external_mod_json_support() {
  stage_dir="$1"
  loadthread="$stage_dir/src/engine/loadthread.lua"

  python3 - "$loadthread" "$MOD_ID" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
mod_id = sys.argv[2]
mod_id_lua = mod_id.replace("\\", "\\\\").replace('"', '\\"')
text = path.read_text()

helper = f'''
local DEBUG_EXTERNAL_MOD_JSON_ID = "{mod_id_lua}"

local function debugJoinPath(left, right)
    if not left or left == "" then
        return right
    end
    if not right or right == "" then
        return left
    end
    if left:sub(-1) == "/" or left:sub(-1) == "\\\\" then
        return left .. right
    end
    return left .. "/" .. right
end

local function debugIsAbsolutePath(path)
    if not path or path == "" then
        return false
    end
    return path:sub(1, 1) == "/"
        or path:match("^%a:[/\\\\]") ~= nil
        or path:sub(1, 2) == "\\\\\\\\"
end

local function debugReadHostFile(path)
    if not path or path == "" or not io or not io.open then
        return nil
    end

    local file = io.open(path, "rb")
    if not file then
        return nil
    end

    local contents = file:read("*a")
    file:close()
    return contents
end

local function debugAddCandidate(candidates, seen, path)
    if not path or path == "" or seen[path] then
        return
    end
    seen[path] = true
    table.insert(candidates, path)
end

local function debugAddRelativeCandidate(candidates, seen, base_dir, relative_path)
    if not base_dir or base_dir == "" then
        return
    end
    debugAddCandidate(candidates, seen, debugJoinPath(base_dir, relative_path))
end

local function debugIsArray(value)
    if type(value) ~= "table" then
        return false
    end

    local count = 0
    for key, _ in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
        if key > count then
            count = key
        end
    end
    for index = 1, count do
        if value[index] == nil then
            return false
        end
    end
    return true
end

local function debugMergeModJson(base, override)
    for key, value in pairs(override) do
        if key ~= "id" and key ~= "folder" and key ~= "path" then
            local base_value = base[key]
            if type(base_value) == "table"
                and type(value) == "table"
                and not debugIsArray(base_value)
                and not debugIsArray(value)
            then
                debugMergeModJson(base_value, value)
            else
                base[key] = value
            end
        end
    end
    return base
end

local function applyExternalModJsonOverride(path, mod)
    if path ~= DEBUG_EXTERNAL_MOD_JSON_ID and mod.id ~= DEBUG_EXTERNAL_MOD_JSON_ID then
        return mod
    end

    local candidates = {{}}
    local seen = {{}}
    local env_path = os.getenv("KRISIS_MOD_JSON")
    local source_base = love.filesystem.getSourceBaseDirectory and love.filesystem.getSourceBaseDirectory() or nil
    local save_dir = love.filesystem.getSaveDirectory and love.filesystem.getSaveDirectory() or nil

    if env_path and env_path ~= "" then
        debugAddCandidate(candidates, seen, env_path)
        if source_base and not debugIsAbsolutePath(env_path) then
            debugAddRelativeCandidate(candidates, seen, source_base, env_path)
        end
    end

    debugAddRelativeCandidate(candidates, seen, source_base, "mod.json")
    debugAddRelativeCandidate(candidates, seen, source_base, "mods/" .. DEBUG_EXTERNAL_MOD_JSON_ID .. "/mod.json")
    debugAddRelativeCandidate(candidates, seen, save_dir, "mod.json")
    debugAddRelativeCandidate(candidates, seen, save_dir, "mods/" .. DEBUG_EXTERNAL_MOD_JSON_ID .. "/mod.json")

    for _, candidate in ipairs(candidates) do
        local contents = debugReadHostFile(candidate)
        if contents then
            local ok, external = pcall(json.decode, contents)
            if ok and type(external) == "table" then
                local embedded_id = mod.id
                debugMergeModJson(mod, external)
                mod.id = embedded_id
                mod.external_mod_json_path = candidate
                print("[DEBUG] Loaded external mod.json override: " .. candidate)
                return mod
            end
            print("[WARNING] External mod.json override is invalid: " .. candidate .. ": " .. tostring(external))
        end
    end

    return mod
end
'''

marker = "verbose = false\n"
if marker not in text:
    raise SystemExit(f"Could not find insertion marker in {path}")
text = text.replace(marker, marker + helper, 1)

needle = '            local ok, mod = pcall(json.decode, love.filesystem.read(full_path .. "/mod.json"))\n'
replacement = needle + '''            if ok then
                mod = applyExternalModJsonOverride(path, mod)
            end
'''
if needle not in text:
    raise SystemExit(f"Could not find mod.json decode site in {path}")
text = text.replace(needle, replacement, 1)
path.write_text(text)
PY
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
      ;;
    debug)
      release_mode="false"
      mod_dev="true"
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
    --exclude='/justfile' \
    --exclude='*.tiled-session' \
    "$MOD_DIR"/ "$staged_mod_dir"/

  copy_overlay_if_set "$variant" "$staged_mod_dir"
  patch_lua_config "$variant" "$stage_dir" "$release_mode"
  patch_mod_manifest "$staged_mod_dir" "$mod_dev"
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
    package_dir="$BUILD_ROOT/$variant/$package_name"
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
      cp "$stage_dir/mods/$MOD_ID/mod.json" "$package_dir/mods/$MOD_ID/mod.json"
      {
        printf 'Debug mod.json override / Debug 版 mod.json 外部覆盖\n'
        printf '\n'
        printf '中文说明\n'
        printf '\n'
        printf '这个 debug 版会先读取 exe 内置的 mod.json，然后尝试读取外部覆盖文件。\n'
        printf '你可以直接编辑本目录下的 mods/%s/mod.json 来覆盖内置配置。\n' "$MOD_ID"
        printf '也可以设置环境变量 KRISIS_MOD_JSON，指向另一个 mod.json 文件路径。\n'
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
        printf 'Edit mods/%s/mod.json next to this executable to override embedded mod.json values.\n' "$MOD_ID"
        printf 'You may also set KRISIS_MOD_JSON to an absolute or relative mod.json path.\n'
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
