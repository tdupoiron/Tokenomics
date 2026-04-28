#!/usr/bin/env bash
# fetch-node.sh — Download and extract the Node.js LTS arm64 binary into
# Resources/embedded-node/ for use by EmbeddedCLIRunner.
#
# Designed to run as an Xcode pre-build phase. Idempotent: skips download
# if the binary is already present and matches the expected version.
#
# Why a script rather than committing the binary: Node.js arm64 is ~30 MB.
# Committing it bloats the git history permanently. The script reproduces the
# exact bytes on any developer machine and on CI, so the repo stays lean.

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────

NODE_VERSION="22.16.0"   # LTS "Jod" — update here when upgrading
NODE_ARCH="arm64"
NODE_PLATFORM="darwin"
NODE_TARBALL="node-v${NODE_VERSION}-${NODE_PLATFORM}-${NODE_ARCH}.tar.gz"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TARBALL}"

# SHA256 of the arm64 macOS tarball for Node 22.16.0.
# Update this when bumping NODE_VERSION above — get from nodejs.org/dist/vX.Y.Z/SHASUMS256.txt
EXPECTED_SHA256="1d7f34ec4c03e12d8b33481e5c4560432d7dc31a0ef3ff5a4d9a8ada7cf6ecc9"

# Resolve the project root relative to this script's location so the script
# works regardless of the working directory Xcode calls it from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEST_DIR="${PROJECT_ROOT}/Tokenomics/Resources/embedded-node"
NODE_BIN="${DEST_DIR}/bin/node"
NPM_BIN="${DEST_DIR}/bin/npm"

# ── Check if already installed ───────────────────────────────────────────────

if [ -f "$NODE_BIN" ] && [ -f "$NPM_BIN" ]; then
    INSTALLED_VERSION=$("$NODE_BIN" --version 2>/dev/null || echo "")
    if [ "$INSTALLED_VERSION" = "v${NODE_VERSION}" ]; then
        echo "[fetch-node] Node.js v${NODE_VERSION} already present — skipping download."
        exit 0
    else
        echo "[fetch-node] Found Node.js ${INSTALLED_VERSION}, expected v${NODE_VERSION} — re-downloading."
    fi
fi

# ── Download ─────────────────────────────────────────────────────────────────

TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

echo "[fetch-node] Downloading Node.js v${NODE_VERSION} arm64…"
curl --silent --show-error --location \
    --retry 3 --retry-delay 2 \
    --output "${TMPDIR_WORK}/${NODE_TARBALL}" \
    "$NODE_URL"

# ── Verify checksum ──────────────────────────────────────────────────────────

echo "[fetch-node] Verifying SHA256 checksum…"
ACTUAL_SHA256=$(shasum -a 256 "${TMPDIR_WORK}/${NODE_TARBALL}" | awk '{print $1}')
if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
    echo "[fetch-node] ERROR: SHA256 mismatch!"
    echo "  Expected: ${EXPECTED_SHA256}"
    echo "  Actual:   ${ACTUAL_SHA256}"
    echo "  If you intentionally bumped NODE_VERSION, update EXPECTED_SHA256 in this script."
    exit 1
fi
echo "[fetch-node] Checksum OK."

# ── Extract only the files we need ───────────────────────────────────────────
#
# We only extract bin/node and bin/npm (plus the npm lib directory npm needs
# to run). Extracting the full 60 MB tarball and then discarding most of it
# keeps the app bundle small while still giving npm enough to function.

echo "[fetch-node] Extracting binaries…"
EXTRACT_PREFIX="node-v${NODE_VERSION}-${NODE_PLATFORM}-${NODE_ARCH}"

tar -xzf "${TMPDIR_WORK}/${NODE_TARBALL}" \
    --directory "$TMPDIR_WORK" \
    "${EXTRACT_PREFIX}/bin/node" \
    "${EXTRACT_PREFIX}/bin/npm" \
    "${EXTRACT_PREFIX}/bin/npx" \
    "${EXTRACT_PREFIX}/lib/node_modules/npm"

# ── Install into Resources/embedded-node/ ────────────────────────────────────

rm -rf "$DEST_DIR"
mkdir -p "${DEST_DIR}/bin"
mkdir -p "${DEST_DIR}/lib"

cp "${TMPDIR_WORK}/${EXTRACT_PREFIX}/bin/node" "${DEST_DIR}/bin/node"
chmod +x "${DEST_DIR}/bin/node"

# npm is a shell script wrapper that calls node + the npm package.
cp "${TMPDIR_WORK}/${EXTRACT_PREFIX}/bin/npm" "${DEST_DIR}/bin/npm"
chmod +x "${DEST_DIR}/bin/npm"

cp "${TMPDIR_WORK}/${EXTRACT_PREFIX}/bin/npx" "${DEST_DIR}/bin/npx"
chmod +x "${DEST_DIR}/bin/npx"

# The npm CLI package itself — npm's wrapper script resolves this at runtime.
cp -r "${TMPDIR_WORK}/${EXTRACT_PREFIX}/lib/node_modules" "${DEST_DIR}/lib/"

# ── Verify ───────────────────────────────────────────────────────────────────

INSTALLED_VERSION=$("${DEST_DIR}/bin/node" --version)
echo "[fetch-node] Installed Node.js ${INSTALLED_VERSION} to ${DEST_DIR}"
echo "[fetch-node] Done."
