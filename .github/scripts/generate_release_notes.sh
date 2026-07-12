#!/usr/bin/env bash
set -euo pipefail

tag="${1:?Usage: generate_release_notes.sh <tag> [output-file]}"
output_file="${2:-release_notes.md}"
script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
security_fragment="$script_dir/release_security_notes.md"

if [ ! -f "$security_fragment" ]; then
  printf 'Security notes fragment does not exist: %s\n' "$security_fragment" >&2
  exit 1
fi

repo="${GITHUB_REPOSITORY:-}"
if [ -z "$repo" ] && command -v gh >/dev/null 2>&1; then
  repo="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
fi
repo_url=""
if [ -n "$repo" ]; then
  repo_url="${GITHUB_SERVER_URL:-https://github.com}/$repo"
fi
target_commitish="${GITHUB_SHA:-}"
current_ref="$tag"

if ! git rev-parse --verify --quiet "${current_ref}^{commit}" >/dev/null; then
  current_ref="${target_commitish:-HEAD}"
fi

if previous_tag="$(git describe --tags --abbrev=0 "${current_ref}^" 2>/dev/null)"; then
  range="$previous_tag..$current_ref"
else
  previous_tag=""
  range="$current_ref"
fi

generated_notes="### Git 提交 / Git Commits"
commit_count=0
while IFS= read -r commit_line || [ -n "$commit_line" ]; do
  commit_count=$((commit_count + 1))
  generated_notes="${generated_notes}"$'\n'"- ${commit_line}"
done < <(git log --pretty=format:'`%h` %s' "$range")

if [ "$commit_count" -eq 0 ]; then
  generated_notes="${generated_notes}"$'\n'"- No commits found."
fi

if [ -n "$repo_url" ]; then
  if [ -n "$previous_tag" ]; then
    generated_notes="${generated_notes}"$'\n\n'"**Full Changelog**: ${repo_url}/compare/${previous_tag}...${tag}"
  else
    generated_notes="${generated_notes}"$'\n\n'"**Full Changelog**: ${repo_url}/commits/${tag}"
  fi
fi

pre_1_notice_zh=""
pre_1_notice_en=""
version_text="${tag#v}"
major_version="${version_text%%.*}"
if [[ "$major_version" =~ ^[0-9]+$ ]] && [ "$major_version" -lt 1 ]; then
  pre_1_notice_zh=$'\n> 这是测试版本，可能不稳定，内容、存档兼容性和功能表现都可能在后续版本中发生变化。请优先下载最新版本；如果遇到问题，反馈时请附上版本号和复现步骤。\n'
  pre_1_notice_en=$'\n> This is a test build and may be unstable. Content, save compatibility, and feature behavior may change in later versions. Please use the latest build when possible; if you run into issues, include the version number and reproduction steps when reporting them.\n'
fi

cat > "$output_file" <<EOF
## 中文

**GitHub Release 和（即将发布的）Gamejolt 页面，是本游戏的官方发布源！**

本游戏是开源的。请务必在官方发布源下载游戏，以确保你获得的是未经篡改、来源明确、版本正确的官方构建，避免第三方重新打包带来的安全风险。
${pre_1_notice_zh}
### 版本说明

- **debug 版本**：开启了 Kristal dev 模式，且支持外部 \`mod.json\` 覆盖。
- **release 版本**：常规版本。

### 下载建议

- 对于 Windows 一般玩家，一般使用 \`*-win64.zip\`，解压即可运行游戏。
- 对于其他用户，可以酌情使用 \`*.love\`，配合 LÖVE 本体运行游戏。

---

## English

**GitHub Releases and the (coming soon) Gamejolt page are the official distribution sources for this game.**

This game is open source. Please download it only from official sources to make sure you get an untampered, clearly sourced, correct official build, and to avoid security risks from third-party repackaging.
${pre_1_notice_en}
### Build Types

- **Debug build**: Enables Kristal dev mode and supports external \`mod.json\` overrides.
- **Release build**: Standard build for normal play.

### Download Guide

- Most Windows players should use \`*-win64.zip\`; extract it and run the game directly.
- Other users may use \`*.love\` with the LÖVE runtime as needed.

EOF
cat "$security_fragment" >> "$output_file"
cat >> "$output_file" <<EOF

---

<details>
<summary><strong>CHANGELOG</strong></summary>

${generated_notes}

</details>
EOF
