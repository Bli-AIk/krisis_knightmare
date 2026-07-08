default: run

build_script := "./build_standalone.sh"

# Run this mod through Kristal in the current terminal.
run:
    #!/usr/bin/env sh
    set -eu

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
    exec love "$engine_root" --mod "$mod_id" --auto-mod-start

# Run this mod through Kristal in a detached terminal.
term:
    @.helix/run-kristal-terminal.sh

# Same as term, but keep the terminal open after Love exits.
hold:
    @.helix/run-kristal-terminal.sh --hold

# Build release and debug standalone packages.
build:
    @{{build_script}}

# Build only the release standalone packages.
build-release:
    @BUILD_VARIANTS=release {{build_script}}

# Build only the debug standalone packages.
build-debug:
    @BUILD_VARIANTS=debug {{build_script}}

# Build only .love archives, without Windows fused zips.
build-love:
    @BUILD_WINDOWS_EXE=0 {{build_script}}

# Build only the release .love archive.
build-love-release:
    @BUILD_VARIANTS=release BUILD_WINDOWS_EXE=0 {{build_script}}

# Build only the debug .love archive.
build-love-debug:
    @BUILD_VARIANTS=debug BUILD_WINDOWS_EXE=0 {{build_script}}

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
