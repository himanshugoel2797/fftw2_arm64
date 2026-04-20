#!/usr/bin/env bash
# Build FFTW 2.1.5 on Apple Silicon (or any host with a modern autotools).
#
# Usage:
#   ./build.sh                # double precision
#   ./build.sh --single       # single precision
#
# Requires autoconf, automake, libtool, patch, curl, make, a C compiler.
# On macOS: brew install autoconf automake libtool
set -euo pipefail

VARIANT="double"
for arg in "$@"; do
    case "$arg" in
        --single) VARIANT="single" ;;
        --double) VARIANT="double" ;;
        -h|--help)
            sed -n '2,11p' "$0"
            exit 0
            ;;
        *) echo "unknown arg: $arg" >&2; exit 2 ;;
    esac
done

FFTW_VERSION="2.1.5"
FFTW_URL="https://www.fftw.org/fftw-${FFTW_VERSION}.tar.gz"
SRC_DIR="fftw-${FFTW_VERSION}"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
PATCH="${REPO_ROOT}/patches/05_ac_define_syntax.diff"

if [ ! -f "${SRC_DIR}.tar.gz" ]; then
    echo ">>> Downloading ${FFTW_URL}"
    curl -fsSL "$FFTW_URL" -o "${SRC_DIR}.tar.gz"
fi

rm -rf "$SRC_DIR"
tar xzf "${SRC_DIR}.tar.gz"

echo ">>> Applying Debian 05_ac_define_syntax.diff"
( cd "$SRC_DIR" && patch -p1 < "$PATCH" )

echo ">>> autoreconf -fvi (regenerates configure + arm64-aware config.sub/guess)"
( cd "$SRC_DIR" && autoreconf -fvi )

CONFIGURE_FLAGS=(--disable-fortran)
if [ "$VARIANT" = "single" ]; then
    CONFIGURE_FLAGS+=(--enable-float)
fi

echo ">>> configure ${CONFIGURE_FLAGS[*]}"
( cd "$SRC_DIR" && ./configure "${CONFIGURE_FLAGS[@]}" )

if [ "$(uname)" = "Darwin" ]; then
    JOBS="$(sysctl -n hw.ncpu)"
else
    JOBS="$(nproc)"
fi

echo ">>> make -j${JOBS}"
( cd "$SRC_DIR" && make -j"$JOBS" )

echo ">>> fftw_test -s 64"
( cd "$SRC_DIR/tests" && ./fftw_test -s 64 )

echo ">>> Build succeeded: $SRC_DIR ($VARIANT precision)"
