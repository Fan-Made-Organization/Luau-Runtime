#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LUAU_SOURCE_DIR="${LUAU_SOURCE_DIR:-$HOME/luau}"
LUAU_BUILD_DIR="${LUAU_BUILD_DIR:-$LUAU_SOURCE_DIR/build}"
LUAU_EXECUTABLE="${LUAU_EXECUTABLE:-$LUAU_BUILD_DIR/luau}"
BUILD_JOBS="${BUILD_JOBS:-2}"

say() { printf '\n[Luau Runtime] %s\n' "$*"; }
fail() { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || fail "Git is required."
command -v cmake >/dev/null 2>&1 || fail "CMake is required."
command -v python3 >/dev/null 2>&1 || fail "Python 3 is required."
command -v make >/dev/null 2>&1 || command -v ninja >/dev/null 2>&1 || fail "A C/C++ build tool (Make or Ninja) is required."

if [[ ! -d "$LUAU_SOURCE_DIR/.git" ]]; then
    say "Cloning the official Luau source into $LUAU_SOURCE_DIR"
    git clone --depth 1 https://github.com/luau-lang/luau.git "$LUAU_SOURCE_DIR"
else
    say "Updating the official Luau source"
    git -C "$LUAU_SOURCE_DIR" pull --ff-only
fi

say "Configuring official Luau CLI"
cmake -S "$LUAU_SOURCE_DIR" -B "$LUAU_BUILD_DIR" -DCMAKE_BUILD_TYPE=Release

say "Building Luau.Repl.CLI (parallel jobs: $BUILD_JOBS)"
cmake --build "$LUAU_BUILD_DIR" --target Luau.Repl.CLI --config Release --parallel "$BUILD_JOBS"

if [[ ! -x "$LUAU_EXECUTABLE" ]]; then
    fail "Luau executable not found or not executable: $LUAU_EXECUTABLE"
fi

cd "$ROOT_DIR"

say "Checking Python syntax"
python3 -m compileall -q config.py main.py gui.py engine interface tests

say "Running Python unit tests"
python3 -m unittest discover -s tests -v

say "Running Luau Super Test"
"$LUAU_EXECUTABLE" scripts/test.luau

say "All build and test stages completed successfully."
