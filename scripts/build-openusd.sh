#!/usr/bin/env bash
set -Eeuo pipefail

# Run inside a prebuilt AlmaLinux/Rocky Linux OpenUSD build image.
# Usage: bash scripts/build-openusd.sh VERSION PLATFORM OUTPUT_DIR
VERSION="${1:?Usage: build-openusd.sh VERSION PLATFORM OUTPUT_DIR}"
PLATFORM="${2:?Missing platform (alma9 or rocky9)}"
OUTPUT_DIR="${3:?Missing output directory}"

case "$PLATFORM" in alma9|rocky9) ;; *) echo "Invalid platform: $PLATFORM" >&2; exit 1 ;; esac

PYTHON_VERSION="${PYTHON_VERSION:-3.10.14}"
GCCCORE_VERSION="${GCCCORE_VERSION:-12.3.0}"
PYTHON_BIN="${PYTHON_BIN:-/pipeline/el9/software/Python/${PYTHON_VERSION}-GCCcore-${GCCCORE_VERSION}/bin/python}"

source /opt/rh/gcc-toolset-12/enable
[[ -x "$PYTHON_BIN" ]] || { echo "Missing Python: $PYTHON_BIN" >&2; exit 1; }
command -v curl >/dev/null
command -v tar >/dev/null

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "** Downloading openUSD v${VERSION} **"
mkdir -p "$WORK/source"
curl -fL --retry 3 \
  "https://github.com/PixarAnimationStudios/OpenUSD/archive/refs/tags/v${VERSION}.tar.gz" \
  -o "$WORK/OpenUSD.tar.gz"

echo "** Extracting openUSD v${VERSION} **"
tar -xzf "$WORK/OpenUSD.tar.gz" --strip-components=1 -C "$WORK/source"

echo "** Building openUSD v${VERSION} **"
"$PYTHON_BIN" "$WORK/source/build_scripts/build_usd.py" \
  "$WORK/_install" \
  --src "$WORK/_src" --build "$WORK/_build" --inst "$WORK/_inst" \
  --build-variant release --python --usd-imaging --usdview \
  --no-tests --no-examples --no-tutorials --no-docs --no-python-docs \
  --materialx --embree --no-onetbb 2>&1 | tee "$OUTPUT_DIR/build.log"

# Preserve the four original build artefacts.
OSD="$WORK/OpenSubdiv"
mkdir -p "$OSD/include" "$OSD/lib"
[[ -d "$WORK/_inst/include/opensubdiv" ]] || { echo 'OpenSubdiv headers missing' >&2; exit 1; }
cp -a "$WORK/_inst/include/opensubdiv" "$OSD/include/"
for LIBDIR in "$WORK/_inst/lib" "$WORK/_inst/lib64"; do
  [[ -d "$LIBDIR" ]] || continue
  find "$LIBDIR" -maxdepth 1 \( -type f -o -type l \) \
    \( -name 'libosd*.so*' -o -name 'libosd*.a' \) -exec cp -a {} "$OSD/lib/" \;
done
[[ -n "$(find "$OSD/lib" -mindepth 1 -maxdepth 1 -print -quit)" ]] || {
  echo 'OpenSubdiv libraries missing' >&2; exit 1;
}
echo "** Creating artifact archives **"
tar -C "$WORK" -czf "$OUTPUT_DIR/OpenUSD_install.tar.gz" _install
tar -C "$WORK" -czf "$OUTPUT_DIR/OpenUSD_build.tar.gz" _build
tar -C "$WORK" -czf "$OUTPUT_DIR/OpenUSD_3rdparty_inst.tar.gz" _inst
tar -C "$WORK" -czf "$OUTPUT_DIR/OpenSubdiv.tar.gz" OpenSubdiv

echo "OpenUSD ${VERSION} (${PLATFORM}) built: ${OUTPUT_DIR}"
