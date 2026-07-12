#!/usr/bin/env bash
set -euo pipefail

input_file="${1:?Usage: append_release_security_notes.sh <input-file> <output-file>}"
output_file="${2:?Usage: append_release_security_notes.sh <input-file> <output-file>}"
script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
security_fragment="$script_dir/release_security_notes.md"
marker='<!-- KRISIS-KNIGHTMARE-SHA256-SECURITY-START -->'

if [[ ! -f "$input_file" ]]; then
  printf 'Release notes file does not exist: %s\n' "$input_file" >&2
  exit 1
fi
if [[ ! -f "$security_fragment" ]]; then
  printf 'Security notes fragment does not exist: %s\n' "$security_fragment" >&2
  exit 1
fi

temporary_output="$(mktemp "${output_file}.XXXXXX")"
trap 'rm -f -- "$temporary_output"' EXIT

if grep -Fq -- "$marker" "$input_file"; then
  cp -- "$input_file" "$temporary_output"
else
  if [[ -s "$input_file" ]]; then
    cat -- "$input_file" > "$temporary_output"
    printf '\n\n' >> "$temporary_output"
  fi
  cat -- "$security_fragment" >> "$temporary_output"
fi

mv -- "$temporary_output" "$output_file"
trap - EXIT
