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


def patch_default_framerate(args: argparse.Namespace) -> None:
    stage_dir = Path(args.stage_dir)
    path = stage_dir / "src/kristal.lua"
    text = read_text(path)
    text = require_substitution(
        text,
        r"(?m)^(\s*fps\s*=\s*)30(\s*,\s*)$",
        r"\g<1>0\g<2>",
        path,
    )
    write_text(path, text)


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


def patch_kristal_startup_credit(args: argparse.Namespace) -> None:
    stage_dir = Path(args.stage_dir)
    path = stage_dir / "src/engine/loadstate.lua"
    text = read_text(path)

    init_needle = '    self.logo_heart = love.graphics.newImage("assets/sprites/kristal/title_logo_heart.png")\n'
    init_replacement = init_needle + '    self.credit_font = love.graphics.newFont("assets/fonts/main.ttf", 8, "mono")\n'
    if init_needle not in text:
        raise SystemExit(f"Could not find Kristal logo initialization in {path}")
    text = text.replace(init_needle, init_replacement, 1)

    skip_needle = "        self:drawSprite(self.logo, 0, 0, 1)\n        love.graphics.pop()\n"
    skip_replacement = "        self:drawSprite(self.logo, 0, 0, 1)\n        self:drawCredit(1, -self.w / 2, self.h / 2 + 4, self.w)\n        love.graphics.pop()\n"
    if skip_needle not in text:
        raise SystemExit(f"Could not find Kristal skip-intro draw site in {path}")
    text = text.replace(skip_needle, skip_replacement, 1)

    draw_method_needle = "function Loading:draw()\n"
    draw_method_replacement = """function Loading:drawCredit(alpha, x, y, width)
    local old_font = love.graphics.getFont()
    local old_r, old_g, old_b, old_a = love.graphics.getColor()

    alpha = math.max(0, math.min(1, alpha or 1))
    love.graphics.setFont(self.credit_font)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf(\"made with\", x, y, width, \"center\")

    love.graphics.setColor(old_r, old_g, old_b, old_a)
    love.graphics.setFont(old_font)
end

function Loading:draw()
"""
    if draw_method_needle not in text:
        raise SystemExit(f"Could not find Kristal loading draw method in {path}")
    text = text.replace(draw_method_needle, draw_method_replacement, 1)

    credit_needle = "    end\n\n    -- Reset canvas to draw to\n    Draw.popCanvas()\n"
    credit_replacement = "    end\n\n    local credit_alpha = self.animation_phase == 0 and (1 - self.factor) or self.logo_alpha\n    self:drawCredit(credit_alpha, self.x, self.y + self.h + 4, self.w)\n\n    -- Reset canvas to draw to\n    Draw.popCanvas()\n"
    if credit_needle not in text:
        raise SystemExit(f"Could not find Kristal loading canvas draw site in {path}")
    text = text.replace(credit_needle, credit_replacement, 1)

    write_text(path, text)


def patch_kristal_startup_resume(args: argparse.Namespace) -> None:
    stage_dir = Path(args.stage_dir)
    path = stage_dir / "src/engine/loadstate.lua"
    text = read_text(path)
    resume_path = lua_quote(
        f"saves/{args.mod_id}/kris_finisher_resume.json"
    )

    init_needle = "    self.h = self.logo:getHeight()\n"
    init_replacement = init_needle + (
        "    self.krisis_resume_intro = love.filesystem.getInfo "
        f"and love.filesystem.getInfo({resume_path}) ~= nil or false\n"
    )
    if init_needle not in text:
        raise SystemExit(f"Could not find Kristal loading dimensions in {path}")
    text = text.replace(init_needle, init_replacement, 1)

    enter_needle = '    if not Kristal.Config["skipIntro"] then\n'
    enter_replacement = (
        '    if not Kristal.Config["skipIntro"] and not self.krisis_resume_intro then\n'
    )
    if enter_needle not in text:
        raise SystemExit(f"Could not find Kristal loading audio branch in {path}")
    text = text.replace(enter_needle, enter_replacement, 1)

    update_needle = (
        '    if (self.loading_state == Loading.States.DONE) and self.key_check '
        'and (self.animation_done or Kristal.Config["skipIntro"]) then\n'
    )
    update_replacement = (
        '    if (self.loading_state == Loading.States.DONE) and self.key_check '
        'and (self.animation_done or Kristal.Config["skipIntro"] '
        'or self.krisis_resume_intro) then\n'
    )
    if update_needle not in text:
        raise SystemExit(f"Could not find Kristal loading completion condition in {path}")
    text = text.replace(update_needle, update_replacement, 1)

    draw_needle = '    if Kristal.Config["skipIntro"] then\n'
    draw_replacement = "    if self.krisis_resume_intro then\n        return\n    end\n\n" + draw_needle
    if draw_needle not in text:
        raise SystemExit(f"Could not find Kristal loading draw branch in {path}")
    text = text.replace(draw_needle, draw_replacement, 1)

    write_text(path, text)


def patch_kristal_https_archive_fallback(args: argparse.Namespace) -> None:
    stage_dir = Path(args.stage_dir)
    path = stage_dir / "src/lib/https.lua"
    text = read_text(path)

    needle = '''local search_paths = { "", (love.filesystem.getRealDirectory("lib/") or "") .. "/lib/" }

local ok, module
for _, search_path in ipairs(search_paths) do
    ok, module = pcall(package.loadlib, search_path .. name, "luaopen_https")

    if not module then
        ok = false
    end

    if ok then
        break
    end
end

HTTPS_AVAILABLE = ok

if not ok then
    return
end

return module()
'''
    replacement = '''local function tryLoadLibrary(path)
    local load_ok, loaded = pcall(package.loadlib, path, "luaopen_https")
    if not loaded then
        load_ok = false
    end
    return load_ok, loaded
end

local search_paths = { "", (love.filesystem.getRealDirectory("lib/") or "") .. "/lib/" }

local ok, module
for _, search_path in ipairs(search_paths) do
    ok, module = tryLoadLibrary(search_path .. name)

    if ok then
        break
    end
end

if not ok and love.filesystem.getInfo and love.filesystem.getInfo("lib/" .. name) then
    -- Native libraries cannot be loaded directly from a .love archive.
    local embedded_data = love.filesystem.read("lib/" .. name)
    local save_directory = love.filesystem.getSaveDirectory and love.filesystem.getSaveDirectory()
    if type(embedded_data) == "string" and save_directory then
        local cache_name = "krisis_" .. name
        local cache_info = love.filesystem.getInfo(cache_name)
        local cache_ready = cache_info and cache_info.size == #embedded_data
        if not cache_ready then
            cache_ready = love.filesystem.write(cache_name, embedded_data)
        end
        if cache_ready then
            ok, module = tryLoadLibrary(save_directory .. "/" .. cache_name)
        end
    end
end

HTTPS_AVAILABLE = ok

if not ok then
    return
end

return module()
'''
    if needle not in text:
        raise SystemExit(f"Could not find Kristal HTTPS loader in {path}")
    text = text.replace(needle, replacement, 1)
    write_text(path, text)


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

    framerate_parser = subparsers.add_parser("patch-default-framerate")
    framerate_parser.add_argument("stage_dir")
    framerate_parser.set_defaults(func=patch_default_framerate)

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

    startup_credit_parser = subparsers.add_parser("patch-kristal-startup-credit")
    startup_credit_parser.add_argument("stage_dir")
    startup_credit_parser.set_defaults(func=patch_kristal_startup_credit)

    startup_resume_parser = subparsers.add_parser("patch-kristal-startup-resume")
    startup_resume_parser.add_argument("stage_dir")
    startup_resume_parser.add_argument("mod_id")
    startup_resume_parser.set_defaults(func=patch_kristal_startup_resume)

    https_archive_parser = subparsers.add_parser("patch-kristal-https-archive-fallback")
    https_archive_parser.add_argument("stage_dir")
    https_archive_parser.set_defaults(func=patch_kristal_https_archive_fallback)

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
