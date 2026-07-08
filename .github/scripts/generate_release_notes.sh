#!/usr/bin/env bash
set -euo pipefail

tag="${1:?Usage: generate_release_notes.sh <tag> [output-file]}"
output_file="${2:-release_notes.md}"

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

cat > "$output_file" <<EOF
## 官方发布源 / Official Release Sources

**GitHub Release 和（即将发布的）Game Jolt 页面是本游戏的官方发布源！**  
**GitHub Releases and the (coming soon) Game Jolt page are the official distribution sources for this game.**

本游戏是开源项目。请务必从官方发布源下载，以降低下载到被篡改、夹带恶意文件、版本过旧或来源不明构建的风险。  
This game is open source. Download only from official sources to reduce the risk of tampered builds, bundled malware, outdated packages, or unknown third-party builds.

## 版本说明 / Build Types

- **debug 版本 / Debug build**：开启 Kristal dev 模式，且支持外部 \`mod.json\` 覆盖。  
  Enables Kristal dev mode and supports external \`mod.json\` overrides.
- **release 版本 / Release build**：常规版本，适合正常游玩。  
  Standard build for normal play.

## 下载建议 / Download Guide

- Windows 一般玩家：下载 \`*-win64.zip\`，解压后直接运行游戏。  
  Most Windows players should download \`*-win64.zip\`, extract it, and run the game directly.
- 其他用户：可按需下载 \`*.love\`，配合 LÖVE 本体运行游戏。  
  Other users may download \`*.love\` and run it with the LÖVE runtime.

## 更新日志 / Changelog

${generated_notes}
EOF
