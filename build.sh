#!/bin/bash
# ======================================================================
# STM32 LL -- one-touch build for configured board
# Usage: ./build.sh [build|flash|clean|rebuild] [--sd-size=...]
#
# Host-specific settings live in env.conf (gitignored).
# Template repo contains no host paths; only chip constants in cmake/boards/.
# Getting started: cp env.conf.example env.conf  then edit your local paths.
# ======================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# -------------------------------------------------------------------------
# 1. Load host-specific env.conf
# -------------------------------------------------------------------------
if [[ ! -f env.conf ]]; then
    echo "==> ERROR: env.conf not found" >&2
    echo "    Run: cp env.conf.example env.conf and edit local paths" >&2
    exit 1
fi
# shellcheck disable=SC1090
source env.conf

if [[ -z "${CUBE_F1_DIR:-}" ]]; then
    echo "==> env.conf missing CUBE_F1_DIR (F1 firmware path)" >&2; exit 1
fi
if [[ -z "${CUBE_F4_DIR:-}" ]]; then
    echo "==> env.conf missing CUBE_F4_DIR (F4 firmware path)" >&2; exit 1
fi
if [[ -z "${BOARD:-}" ]]; then
    boards="$(cd cmake/boards 2>/dev/null && ls *.cmake 2>/dev/null | sed 's/.cmake//' | tr '\n' ' ')"
    echo "==> env.conf missing BOARD. Available: ${boards:-none}" >&2; exit 1
fi

# PYOCD target: derive from BOARD if user did not set it explicitly
if [[ -z "${PYOCD_TARGET:-}" ]]; then
    case "$BOARD" in
        stm32f103c8t6) PYOCD_TARGET="${PYOCD_F1_TARGET:-stm32f103c8}" ;;
        stm32f407vgtx) PYOCD_TARGET="${PYOCD_F4_TARGET:-stm32f407vg}" ;;
        *)
            echo "==> Unknown board: $BOARD (cannot derive pyOCD target)" >&2
            exit 1
            ;;
    esac
fi

# -------------------------------------------------------------------------
# 1.5 Check prerequisites (友好报错前先检查)
# -------------------------------------------------------------------------
for _preq in cmake pyocd arm-none-eabi-size; do
    if ! command -v "$_preq" >/dev/null 2>&1; then
        echo "==> ERROR: $_preq not found in PATH" >&2
        exit 1
    fi
done
unset _preq

# Portable CPU count (macOS 用 sysctl, Linux/MSYS2 用 nproc)
_NCPU_MAC="$(sysctl -n hw.ncpu 2>/dev/null || echo 0)"
_NCPU_LIN="$(nproc 2>/dev/null || echo 0)"
NCPU="$(( _NCPU_MAC > 0 ? _NCPU_MAC : (_NCPU_LIN > 0 ? _NCPU_LIN : 2) ))"
unset _NCPU_MAC _NCPU_LIN

# -------------------------------------------------------------------------
# 2. Parse args
# -------------------------------------------------------------------------
ACTION="build"
SD_SIZE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        build|flash|clean|rebuild) ACTION="$1" ;;
        --sd-size=*) SD_SIZE="${1#*=}" ;;
        -h|--help)
            sed -n '3,14p' "$0" | sed 's/^#\s\?//'; exit 0 ;;
        *) echo "==> Unknown arg: $1" >&2; exit 1 ;;
    esac
    shift
done

# -------------------------------------------------------------------------
# 3. Assemble CMake args
# -------------------------------------------------------------------------
BUILD_DIR="build"
CMAKE_ARGS=(
    -DBOARD="$BOARD"
    -DCUBE_F1_DIR="$CUBE_F1_DIR"
    -DCUBE_F4_DIR="$CUBE_F4_DIR"
    -DPYOCD_TARGET="$PYOCD_TARGET"
)
if [[ -n "$SD_SIZE" ]]; then
    CMAKE_ARGS+=(-DSD_SIZE="$SD_SIZE")
fi
if [[ -n "${SYS_CLK_FREQ:-}" ]]; then
    CMAKE_ARGS+=(-DSYS_CLK_FREQ="$SYS_CLK_FREQ")
fi

# -------------------------------------------------------------------------
# 4. Run
# -------------------------------------------------------------------------
_build() {
    echo "==> Configuring (board=$BOARD @ $(date +%T))..."
    cmake -S . -B "$BUILD_DIR" \
        -DCMAKE_TOOLCHAIN_FILE="cmake/toolchain-arm-none-eabi.cmake" \
        "${CMAKE_ARGS[@]}"
    echo "==> Building..."
    cmake --build "$BUILD_DIR" -j"$NCPU"
}

case "$ACTION" in
    build)
        _build
        ;;
    rebuild)
        echo "==> Cleaning $BUILD_DIR/"
        rm -rf "$BUILD_DIR"
        _build
        ;;
    flash)
        _build
        echo "==> Flashing (target=$PYOCD_TARGET)..."
        cmake --build "$BUILD_DIR" --target flash
        ;;
    clean)
        echo "==> Cleaning $BUILD_DIR/"
        rm -rf "$BUILD_DIR"
        ;;
esac
