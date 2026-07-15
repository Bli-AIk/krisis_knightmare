#!/usr/bin/env bash
set -euo pipefail

tag="${1:?Usage: generate_release_notes.sh <tag> [output-file]}"
output_file="${2:-release_notes.md}"
script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
temporary_intro="$(mktemp "${output_file}.intro.XXXXXX")"
trap 'rm -f -- "$temporary_intro"' EXIT

"$script_dir/generate_release_notes_intro.sh" "$tag" "$temporary_intro"

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

cat "$temporary_intro" > "$output_file"
cat >> "$output_file" <<EOF

---

<details>
<summary><strong>CHANGELOG</strong></summary>

${generated_notes}

</details>
EOF
trap - EXIT
