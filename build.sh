#!/usr/bin/env bash
# Build FFTW 2.1.5 on Apple Silicon (or any host with a modern autotools).
#
# Usage:
#   ./build.sh                # double precision
#   ./build.sh --single       # single precision
#
# Produces, under ./dist/ :
#   fftw-2.1.5-patched.tar.gz            Source tree after the Debian patch
#                                        and autoreconf — ready to
#                                        `./configure && make` on any
#                                        modern host, including arm64.
#   install-<variant>/usr/local/...      Install tree from `make install`.
#                                        Contains lib/libfftw.* (or
#                                        libsfftw.* for single precision),
#                                        include/*.h, bin/fftw-wisdom-*,
#                                        etc.
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
            sed -n '2,20p' "$0"
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
DIST_DIR="${REPO_ROOT}/dist"
PATCHED_TARBALL="${DIST_DIR}/fftw-${FFTW_VERSION}-patched.tar.gz"
INSTALL_ROOT="${DIST_DIR}/install-${VARIANT}"

mkdir -p "$DIST_DIR"

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

echo ">>> Packaging patched source → ${PATCHED_TARBALL}"
rm -f "$PATCHED_TARBALL"
tar czf "$PATCHED_TARBALL" "$SRC_DIR"

CONFIGURE_FLAGS=(--prefix=/usr/local --disable-fortran)
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

echo ">>> make install DESTDIR=${INSTALL_ROOT}"
rm -rf "$INSTALL_ROOT"
( cd "$SRC_DIR" && make install DESTDIR="$INSTALL_ROOT" )

echo ">>> Installed files:"
find "$INSTALL_ROOT" -type f | sort

echo ">>> Build succeeded: $VARIANT precision"
echo "    Patched source: $PATCHED_TARBALL"
echo "    Install tree:   $INSTALL_ROOT"
