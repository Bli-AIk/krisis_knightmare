#!/usr/bin/env bash
set -euo pipefail

tag="${1:?Usage: prepare_release_notes.sh <tag> <input-file> <output-file>}"
input_file="${2:?Usage: prepare_release_notes.sh <tag> <input-file> <output-file>}"
output_file="${3:?Usage: prepare_release_notes.sh <tag> <input-file> <output-file>}"
script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$input_file" ]]; then
  printf 'Release notes file does not exist: %s\n' "$input_file" >&2
  exit 1
fi

temporary_intro="$(mktemp "${output_file}.intro.XXXXXX")"
temporary_clean="$(mktemp "${output_file}.clean.XXXXXX")"
temporary_changelog="$(mktemp "${output_file}.changelog.XXXXXX")"
temporary_output="$(mktemp "${output_file}.XXXXXX")"
trap 'rm -f -- "$temporary_intro" "$temporary_clean" "$temporary_changelog" "$temporary_output"' EXIT

"$script_dir/generate_release_notes_intro.sh" "$tag" "$temporary_intro"

# Remove both the current canonical intro and the legacy end-of-notes security block.
awk '
  /<!-- KRISIS-KNIGHTMARE-RELEASE-INTRO-START -->/ { in_intro = 1; next }
  /<!-- KRISIS-KNIGHTMARE-RELEASE-INTRO-END -->/ { in_intro = 0; next }
  /<!-- KRISIS-KNIGHTMARE-SHA256-SECURITY-START -->/ { in_security = 1; next }
  /<!-- KRISIS-KNIGHTMARE-SHA256-SECURITY-END -->/ { in_security = 0; next }
  !in_intro && !in_security { print }
' "$input_file" > "$temporary_clean"

if grep -Fq -- '<details>' "$temporary_clean"; then
  sed -n '/<details>/,$p' "$temporary_clean" > "$temporary_changelog"
  has_wrapped_changelog=1
else
  cp -- "$temporary_clean" "$temporary_changelog"
  has_wrapped_changelog=0
fi

cat "$temporary_intro" > "$temporary_output"
if [[ -s "$temporary_changelog" ]]; then
  printf '\n\n---\n\n' >> "$temporary_output"
  if [[ "$has_wrapped_changelog" -eq 1 ]]; then
    cat "$temporary_changelog" >> "$temporary_output"
  else
    cat >> "$temporary_output" <<'EOF'
<details>
<summary><strong>CHANGELOG</strong></summary>

EOF
    cat "$temporary_changelog" >> "$temporary_output"
    cat >> "$temporary_output" <<'EOF'

</details>
EOF
  fi
fi

mv -- "$temporary_output" "$output_file"
trap - EXIT
