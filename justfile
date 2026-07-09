default: run

build_script := "./build_standalone.sh"

# Run this mod through Kristal in the current terminal.
run *args:
    #!/usr/bin/env bash
    set -euo pipefail
    set -- {{ args }}

    usage() {
      printf '%s\n' \
        'usage: just run [--encounter [id]|-e [id]] [--wave n|-w n] [--wave-force n|-wf n]' \
        '' \
        '  --encounter, -e       Start directly in an encounter. Defaults to "kris".' \
        '  --wave, -w            Start the encounter from a specific wave number.' \
        '  --wave-force, -wf     Lock the encounter to a specific wave number.'
    }

    kristal_args=()
    encounter_requested=0
    wave_requested=0

    require_value() {
      local flag=$1
      local value=${2:-}
      if [ -z "$value" ]; then
        echo "$flag requires a value." >&2
        exit 64
      fi
      printf '%s\n' "$value"
    }

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --)
          shift
          ;;
        --help|-h)
          usage
          exit 0
          ;;
        --encounter=*)
          encounter_requested=1
          value=${1#--encounter=}
          kristal_args+=(--encounter "${value:-kris}")
          shift
          ;;
        --encounter|-e)
          encounter_requested=1
          if [ "$#" -gt 1 ] && [[ "$2" != -* ]]; then
            kristal_args+=(--encounter "$2")
            shift 2
          else
            kristal_args+=(--encounter kris)
            shift
          fi
          ;;
        -e?*)
          encounter_requested=1
          kristal_args+=(--encounter "${1#-e}")
          shift
          ;;
        --wave-force=*)
          wave_requested=1
          kristal_args+=(--wave-force "$(require_value --wave-force "${1#--wave-force=}")")
          shift
          ;;
        --wave-force|-wf)
          wave_requested=1
          if [ "$#" -le 1 ]; then
            echo "$1 requires a value." >&2
            exit 64
          fi
          kristal_args+=(--wave-force "$2")
          shift 2
          ;;
        -wf?*)
          wave_requested=1
          kristal_args+=(--wave-force "$(require_value -wf "${1#-wf}")")
          shift
          ;;
        --wave=*)
          wave_requested=1
          kristal_args+=(--wave "$(require_value --wave "${1#--wave=}")")
          shift
          ;;
        --wave|-w)
          wave_requested=1
          if [ "$#" -le 1 ]; then
            echo "$1 requires a value." >&2
            exit 64
          fi
          kristal_args+=(--wave "$2")
          shift 2
          ;;
        -w?*)
          wave_requested=1
          kristal_args+=(--wave "$(require_value -w "${1#-w}")")
          shift
          ;;
        -*)
          echo "unknown run option: $1" >&2
          usage >&2
          exit 64
          ;;
        *)
          kristal_args+=("$1")
          shift
          ;;
      esac
    done

    if [ "$wave_requested" -eq 1 ] && [ "$encounter_requested" -eq 0 ]; then
      kristal_args+=(--encounter kris)
    fi

    mod_root=$(pwd -P)

    mod_id=""
    if [ -f "$mod_root/mod.json" ]; then
      mod_id=$(sed -n 's/^[[:space:]]*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*$/\1/p' "$mod_root/mod.json" | head -n 1)
    fi
    if [ -z "$mod_id" ]; then
      mod_id=$(basename "$mod_root")
    fi

    engine_root="${KRISTAL_ROOT:-}"
    if [ -z "$engine_root" ]; then
      for candidate in \
        "$mod_root/../Kristal" \
        "$mod_root/../kristal" \
        "$mod_root/../../Kristal" \
        "$mod_root/../../kristal" \
        "$HOME/Projects/LuaProjects/Kristal" \
        "$HOME/Projects/Kristal" \
        "$HOME/Kristal"
      do
        if [ -f "$candidate/main.lua" ]; then
          engine_root=$(CDPATH= cd "$candidate" && pwd -P)
          break
        fi
      done
    fi

    if [ -z "$engine_root" ]; then
      echo "Kristal engine not found. Set KRISTAL_ROOT=/path/to/Kristal." >&2
      exit 1
    fi

    if [ ! -f "$engine_root/main.lua" ]; then
      echo "Kristal engine main.lua not found: $engine_root/main.lua" >&2
      exit 1
    fi

    cd "$engine_root"
    exec love "$engine_root" --mod "$mod_id" --auto-mod-start "${kristal_args[@]}"

# Run this mod through Kristal in a detached terminal.
term:
    @.helix/run-kristal-terminal.sh

# Same as term, but keep the terminal open after Love exits.
hold:
    @.helix/run-kristal-terminal.sh --hold

# Build release and debug standalone packages.
build:
    @{{ build_script }}

# Build only the release standalone packages.
build-release:
    @BUILD_VARIANTS=release {{ build_script }}

# Build only the debug standalone packages.
build-debug:
    @BUILD_VARIANTS=debug {{ build_script }}

# Build only .love archives, without Windows fused zips.
build-love:
    @BUILD_WINDOWS_EXE=0 {{ build_script }}

# Build only the release .love archive.
build-love-release:
    @BUILD_VARIANTS=release BUILD_WINDOWS_EXE=0 {{ build_script }}

# Build only the debug .love archive.
build-love-debug:
    @BUILD_VARIANTS=debug BUILD_WINDOWS_EXE=0 {{ build_script }}

# Remove standalone build intermediates and artifacts.
clean-build:
    rm -rf .build dist

# List generated standalone artifacts.
artifacts:
    @find dist -maxdepth 1 -type f -print 2>/dev/null | sort || true

alias l := run
alias t := term
alias L := hold
alias b := build
alias br := build-release
alias bd := build-debug
