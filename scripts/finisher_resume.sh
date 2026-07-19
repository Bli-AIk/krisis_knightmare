#!/bin/sh
set -eu

action=${1:-}
save_root=${KRISTAL_SAVE_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/love/kristal}
marker_dir="$save_root/saves/krisis_knightmare"
marker_file="$marker_dir/kris_finisher_resume.json"

usage() {
    printf '%s\n' \
        "usage: $0 add|clear|status" \
        "  add     Add the finisher resume marker." \
        "  clear   Remove the finisher resume marker." \
        "  status  Show whether the marker exists."
}

case "$action" in
    add)
        mkdir -p "$marker_dir"
        printf '%s\n' '{"version":1,"encounter":"kris_finisher"}' > "$marker_file"
        printf 'Added finisher resume marker: %s\n' "$marker_file"
        ;;
    clear)
        if [ -f "$marker_file" ]; then
            rm -f "$marker_file"
            printf 'Cleared finisher resume marker: %s\n' "$marker_file"
        else
            printf 'Finisher resume marker is already clear: %s\n' "$marker_file"
        fi
        ;;
    status)
        if [ -f "$marker_file" ]; then
            printf 'Finisher resume marker: present (%s)\n' "$marker_file"
        else
            printf 'Finisher resume marker: absent (%s)\n' "$marker_file"
        fi
        ;;
    *)
        usage >&2
        exit 64
        ;;
esac
