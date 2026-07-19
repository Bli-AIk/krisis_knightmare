#!/usr/bin/env bash
set -euo pipefail

tag="${1:?Usage: generate_release_notes_intro.sh <tag> <output-file>}"
output_file="${2:?Usage: generate_release_notes_intro.sh <tag> <output-file>}"
script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
zh_security="$script_dir/release_security_notes_zh.md"
en_security="$script_dir/release_security_notes_en.md"

for file in "$zh_security" "$en_security"; do
  if [[ ! -f "$file" ]]; then
    printf 'Release notes fragment does not exist: %s\n' "$file" >&2
    exit 1
  fi
done

pre_1_notice_zh=""
pre_1_notice_en=""
version_text="${tag#v}"
major_version="${version_text%%.*}"
if [[ "$major_version" =~ ^[0-9]+$ ]] && [[ "$major_version" -lt 1 ]]; then
  pre_1_notice_zh=$'\n> 这是测试版本，可能不稳定，内容、存档兼容性和功能表现都可能在后续版本中发生变化。请优先下载最新版本；如果遇到问题，反馈时请附上版本号和复现步骤。\n'
  pre_1_notice_en=$'\n> This is a test build and may be unstable. Content, save compatibility, and feature behavior may change in later versions. Please use the latest build when possible; if you run into issues, include the version number and reproduction steps when reporting them.\n'
fi

temporary_output="$(mktemp "${output_file}.XXXXXX")"
trap 'rm -f -- "$temporary_output"' EXIT

cat > "$temporary_output" <<EOF
<!-- KRISIS-KNIGHTMARE-RELEASE-INTRO-START -->
## 中文

**GitHub Releases、GameBanana 和 Gamejolt 都是本游戏的官方发布源。目前 GitHub Releases 已开放，GameBanana 和 Gamejolt 页面正在准备中，即将发布。**

本游戏是开源的。请务必在官方发布源下载游戏，以确保你获得的是未经篡改、来源明确、版本正确的官方构建，避免第三方重新打包带来的安全风险。
${pre_1_notice_zh}
### 版本说明

- **mod 包**：krisis-knightmare-mod.zip，需要 Kristal v0.10.0。这是实验性的项目包形式，尚未经过完整验证，但理论上可行。
- **debug 版本**：开启了 Kristal dev 模式，且支持外部 \`mod.json\` 覆盖。
- **release 版本**：常规版本。

### 下载建议

- 已安装 Kristal 的用户可以尝试 krisis-knightmare-mod.zip，将 ZIP 直接放入 Kristal 主菜单打开的 projects 文件夹（源码运行时对应 mods/ 目录），并确保 ZIP 根目录直接包含 mod.json。
- 对于 Windows 一般玩家，一般使用 \`*-win64.zip\`，解压即可运行游戏。
- 对于其他用户，可以酌情使用 \`*.love\`，配合 LÖVE 本体运行游戏。

<details>
<summary>关于 mod 运行方式和构建版 Kristal 修改</summary>

本项目就是在 Kristal 的 mod 运行方式下开发的，开发时项目位于 Kristal 的 mods/ 目录中。mod 包不包含 standalone 构建时使用的修改版 Kristal 引擎。

为了制作 standalone，构建脚本只在临时构建副本中对 Kristal 做轻度修改，包括设置目标项目并自动启动、修改窗口标题和身份、取消默认帧率限制、显示启动画面的 made with 署名、根据 finisher 恢复记录跳过启动动画、让 .love 中的 HTTPS 原生库可以先释放到存档目录、在 release 中关闭 DebugSystem 输入钩子，以及在 debug 中支持外部 mod.json 覆盖。这些修改不会写入仓库中的 Kristal，也不会进入 mod 包。

因此，mod 形式单独运行尚未经过完整验证；目前只能说从项目结构和开发方式来看理论上可行。
</details>

EOF
cat "$zh_security" >> "$temporary_output"
cat >> "$temporary_output" <<EOF

---

## English

**GitHub Releases, GameBanana, and Gamejolt are all official distribution sources for this game. GitHub Releases is currently available; the GameBanana and Gamejolt pages are being prepared and will be available soon.**

This game is open source. Please download it only from official sources to make sure you get an untampered, clearly sourced, correct official build, and to avoid security risks from third-party repackaging.
${pre_1_notice_en}
### Build Types

- **Mod package**: krisis-knightmare-mod.zip, which requires Kristal v0.10.0. This project-package form is experimental and has not been fully verified, although it should be theoretically possible.
- **Debug build**: Enables Kristal dev mode and supports external \`mod.json\` overrides.
- **Release build**: Standard build for normal play.

### Download Guide

- Users who already have Kristal may try krisis-knightmare-mod.zip by placing it directly in the projects folder opened from Kristal's main menu (the source version uses the mods/ directory); the ZIP root must contain mod.json directly.
- Most Windows players should use \`*-win64.zip\`; extract it and run the game directly.
- Other users may use \`*.love\` with the LÖVE runtime as needed.

<details>
<summary>About the mod workflow and the modified Kristal used for builds</summary>

This project was developed as a Kristal project from Kristal's mods/ directory. The mod package does not include the modified Kristal engine used by standalone builds.

To create standalone builds, the build scripts apply small changes only to a temporary Kristal build copy: setting the target project and automatic startup, changing the window title and identity, removing the default frame-rate cap, displaying a made with credit on the startup screen, skipping the startup animation when a finisher resume record is found, extracting the HTTPS native library from a .love archive to the save directory before loading, disabling DebugSystem input hooks in release builds, and supporting external mod.json overrides in debug builds. These changes are not written to the Kristal source repository and are not included in the mod package.

The mod form has therefore not been fully verified on its own; based on the project structure and development workflow, it should only be considered theoretically possible for now.
</details>

EOF
cat "$en_security" >> "$temporary_output"
cat >> "$temporary_output" <<'EOF'

<!-- KRISIS-KNIGHTMARE-RELEASE-INTRO-END -->
EOF

mv -- "$temporary_output" "$output_file"
trap - EXIT
