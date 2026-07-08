#!/usr/bin/env python3
import argparse
import re
import sys
import zipfile
from pathlib import Path


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")


def lua_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def require_substitution(text: str, pattern: str, replacement: str, path: Path, flags: int = 0) -> str:
    patched, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f"Could not patch {pattern} in {path}")
    return patched


def zip_dir(args: argparse.Namespace) -> None:
    output_file = Path(args.output_file)
    source_dir = Path(args.source_dir)
    prefix = args.prefix.strip("/")

    output_file.parent.mkdir(parents=True, exist_ok=True)
    if output_file.exists():
        output_file.unlink()

    with zipfile.ZipFile(output_file, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(source_dir.rglob("*")):
            if not path.is_file():
                continue
            rel = path.relative_to(source_dir).as_posix()
            arcname = f"{prefix}/{rel}" if prefix else rel
            archive.write(path, arcname)


def print_lua_string(args: argparse.Namespace) -> None:
    print(lua_quote(args.value))


def patch_lua_config(args: argparse.Namespace) -> None:
    stage_dir = Path(args.stage_dir)
    vendcust_path = stage_dir / "src/engine/vendcust.lua"
    conf_path = stage_dir / "conf.lua"

    mod_id = args.mod_id.replace("\\", "\\\\").replace('"', '\\"')
    text = read_text(vendcust_path)
    replacements = {
        r"(?m)^TARGET_MOD\s*=.*$": f'TARGET_MOD = "{mod_id}"',
        r"(?m)^AUTO_MOD_START\s*=.*$": "AUTO_MOD_START = true",
        r"(?m)^RELEASE_MODE\s*=.*$": f"RELEASE_MODE = {args.release_mode}",
    }
    for pattern, replacement in replacements.items():
        text = require_substitution(text, pattern, replacement, vendcust_path)
    write_text(vendcust_path, text)

    identity = lua_quote(args.identity)
    title = lua_quote(args.title)
    text = read_text(conf_path)
    replacements = {
        r"(?m)^(\s*t\.identity\s*=\s*).*$": rf"\g<1>{identity}",
        r"(?m)^(\s*t\.window\.title\s*=\s*).*$": rf"\g<1>{title}",
    }
    for pattern, replacement in replacements.items():
        text = require_substitution(text, pattern, replacement, conf_path)
    write_text(conf_path, text)


def patch_mod_manifest(args: argparse.Namespace) -> None:
    path = Path(args.manifest)
    text = read_text(path)

    text = require_substitution(text, r'("dev"\s*:\s*)(true|false)', rf"\g<1>{args.mod_dev}", path)
    text = require_substitution(
        text,
        r'("object-editor"\s*:\s*\{.*?"enabled"\s*:\s*)(true|false)',
        rf"\g<1>{args.object_editor_enabled}",
        path,
        flags=re.S,
    )
    text = require_substitution(
        text,
        r'("wave-video-debug"\s*:\s*\{.*?"enabled"\s*:\s*)(true|false)',
        r"\g<1>false",
        path,
        flags=re.S,
    )

    write_text(path, text)


DEBUG_EXTERNAL_MOD_JSON_HELPER = r'''
local DEBUG_EXTERNAL_MOD_JSON_ID = "{mod_id_lua}"

local function debugJoinPath(left, right)
    if not left or left == "" then
        return right
    end
    if not right or right == "" then
        return left
    end
    if left:sub(-1) == "/" or left:sub(-1) == "\\" then
        return left .. right
    end
    return left .. "/" .. right
end

local function debugDirName(path)
    if not path or path == "" then
        return nil
    end

    local normalized = path:gsub("\\", "/")
    local directory = normalized:match("^(.*)/[^/]*$")
    if directory and directory ~= "" then
        return directory
    end
    return nil
end

local function debugIsAbsolutePath(path)
    if not path or path == "" then
        return false
    end
    return path:sub(1, 1) == "/"
        or path:match("^%a:[/\\]") ~= nil
        or path:sub(1, 2) == "\\\\"
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

local function debugAddModJsonCandidates(candidates, seen, base_dir)
    debugAddRelativeCandidate(candidates, seen, base_dir, "mod.json")
    debugAddRelativeCandidate(candidates, seen, base_dir, "mods/" .. DEBUG_EXTERNAL_MOD_JSON_ID .. "/mod.json")
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

local function debugExternalModJsonLog(save_dir, message)
    print(message)

    if not save_dir or not io or not io.open then
        return
    end

    local file = io.open(debugJoinPath(save_dir, "external_mod_json.log"), "a")
    if not file then
        return
    end
    file:write(message, "\n")
    file:close()
end

local function applyExternalModJsonOverride(path, mod)
    if path ~= DEBUG_EXTERNAL_MOD_JSON_ID and mod.id ~= DEBUG_EXTERNAL_MOD_JSON_ID then
        return mod
    end

    local candidates = {{}}
    local seen = {{}}
    local env_path = os.getenv("KRISIS_MOD_JSON")
    local source_path = love.filesystem.getSource and love.filesystem.getSource() or nil
    local source_dir = debugDirName(source_path)
    local source_base = love.filesystem.getSourceBaseDirectory and love.filesystem.getSourceBaseDirectory() or nil
    local working_dir = love.filesystem.getWorkingDirectory and love.filesystem.getWorkingDirectory() or nil
    local save_dir = love.filesystem.getSaveDirectory and love.filesystem.getSaveDirectory() or nil

    if env_path and env_path ~= "" then
        debugAddCandidate(candidates, seen, env_path)
        if working_dir and not debugIsAbsolutePath(env_path) then
            debugAddRelativeCandidate(candidates, seen, working_dir, env_path)
        end
        if source_dir and not debugIsAbsolutePath(env_path) then
            debugAddRelativeCandidate(candidates, seen, source_dir, env_path)
        end
        if source_base and not debugIsAbsolutePath(env_path) then
            debugAddRelativeCandidate(candidates, seen, source_base, env_path)
        end
    end

    debugAddModJsonCandidates(candidates, seen, source_path)
    debugAddModJsonCandidates(candidates, seen, source_dir)
    debugAddModJsonCandidates(candidates, seen, source_base)
    debugAddModJsonCandidates(candidates, seen, working_dir)
    debugAddModJsonCandidates(candidates, seen, save_dir)

    for _, candidate in ipairs(candidates) do
        local contents = debugReadHostFile(candidate)
        if contents then
            local ok, external = pcall(json.decode, contents)
            if ok and type(external) == "table" then
                local embedded_id = mod.id
                debugMergeModJson(mod, external)
                mod.id = embedded_id
                mod.external_mod_json_path = candidate
                debugExternalModJsonLog(save_dir, "[DEBUG] Loaded external mod.json override: " .. candidate)
                return mod
            end
            debugExternalModJsonLog(save_dir, "[WARNING] External mod.json override is invalid: " .. candidate .. ": " .. tostring(external))
        end
    end

    debugExternalModJsonLog(save_dir, "[DEBUG] No external mod.json override found. Checked: " .. table.concat(candidates, " | "))
    return mod
end
'''


def patch_debug_external_mod_json(args: argparse.Namespace) -> None:
    path = Path(args.loadthread)
    mod_id_lua = args.mod_id.replace("\\", "\\\\").replace('"', '\\"')
    text = read_text(path)

    marker = "verbose = false\n"
    if marker not in text:
        raise SystemExit(f"Could not find insertion marker in {path}")
    text = text.replace(marker, marker + DEBUG_EXTERNAL_MOD_JSON_HELPER.format(mod_id_lua=mod_id_lua), 1)

    needle = '            local ok, mod = pcall(json.decode, love.filesystem.read(full_path .. "/mod.json"))\n'
    replacement = needle + '''            if ok then
                mod = applyExternalModJsonOverride(path, mod)
            end
'''
    if needle not in text:
        raise SystemExit(f"Could not find mod.json decode site in {path}")
    text = text.replace(needle, replacement, 1)
    write_text(path, text)


def patch_kristal_v010_release_debug_input(args: argparse.Namespace) -> None:
    stage_dir = Path(args.stage_dir)
    version_path = stage_dir / "VERSION"
    version = read_text(version_path).strip()
    if version != "0.10.0":
        print(f"[build] Skipping release DebugSystem input patch for Kristal VERSION={version}", file=sys.stderr)
        return

    path = stage_dir / "src/kristal.lua"
    text = read_text(path)
    patched = text
    replacements = [
        ("    if Kristal.DebugSystem then\n        Kristal.DebugSystem:onMousePressed", "    if Kristal.DebugSystem and not RELEASE_MODE then\n        Kristal.DebugSystem:onMousePressed"),
        ("    if Kristal.DebugSystem then\n        Kristal.DebugSystem:onMouseReleased", "    if Kristal.DebugSystem and not RELEASE_MODE then\n        Kristal.DebugSystem:onMouseReleased"),
        ("    if Kristal.DebugSystem then\n        Kristal.DebugSystem:onKeyPressed", "    if Kristal.DebugSystem and not RELEASE_MODE then\n        Kristal.DebugSystem:onKeyPressed"),
        ("    if Kristal.DebugSystem then\n        Kristal.DebugSystem:onKeyReleased", "    if Kristal.DebugSystem and not RELEASE_MODE then\n        Kristal.DebugSystem:onKeyReleased"),
        ("    if Kristal.DebugSystem then\n        Kristal.DebugSystem:onWheelMoved", "    if Kristal.DebugSystem and not RELEASE_MODE then\n        Kristal.DebugSystem:onWheelMoved"),
    ]
    for needle, replacement in replacements:
        if needle not in patched:
            raise SystemExit(f"Could not find DebugSystem input hook in {path}: {needle!r}")
        patched = patched.replace(needle, replacement, 1)

    if patched == text:
        raise SystemExit(f"Release DebugSystem input patch made no changes in {path}")

    write_text(path, patched)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Build helper for KRISIS standalone packages.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    zip_parser = subparsers.add_parser("zip-dir")
    zip_parser.add_argument("output_file")
    zip_parser.add_argument("source_dir")
    zip_parser.add_argument("prefix", nargs="?", default="")
    zip_parser.set_defaults(func=zip_dir)

    lua_parser = subparsers.add_parser("lua-string")
    lua_parser.add_argument("value")
    lua_parser.set_defaults(func=print_lua_string)

    lua_config_parser = subparsers.add_parser("patch-lua-config")
    lua_config_parser.add_argument("stage_dir")
    lua_config_parser.add_argument("mod_id")
    lua_config_parser.add_argument("release_mode")
    lua_config_parser.add_argument("identity")
    lua_config_parser.add_argument("title")
    lua_config_parser.set_defaults(func=patch_lua_config)

    manifest_parser = subparsers.add_parser("patch-mod-manifest")
    manifest_parser.add_argument("manifest")
    manifest_parser.add_argument("mod_dev")
    manifest_parser.add_argument("object_editor_enabled")
    manifest_parser.set_defaults(func=patch_mod_manifest)

    external_parser = subparsers.add_parser("patch-debug-external-mod-json")
    external_parser.add_argument("loadthread")
    external_parser.add_argument("mod_id")
    external_parser.set_defaults(func=patch_debug_external_mod_json)

    release_debug_parser = subparsers.add_parser("patch-kristal-v010-release-debug-input")
    release_debug_parser.add_argument("stage_dir")
    release_debug_parser.set_defaults(func=patch_kristal_v010_release_debug_input)

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
