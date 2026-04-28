#!/usr/bin/env bash
# check-embedded-node.sh — Post-build smoke test for the embedded Node binary.
#
# Run after building a Release archive to confirm:
#   1. The embedded node binary exists in the built app bundle
#   2. It is signed with a Developer ID identity (required for notarization)
#   3. The hardened runtime flag is set (also required for notarization)
#
# Usage:
#   ./scripts/check-embedded-node.sh /path/to/Tokenomics.app
#   ./scripts/check-embedded-node.sh  # auto-finds the most recent DerivedData build

set -euo pipefail

# ── Locate the app bundle ────────────────────────────────────────────────────

if [ $# -ge 1 ]; then
    APP_BUNDLE="$1"
else
    # Search in common DerivedData paths
    APP_BUNDLE=$(find ~/Library/Developer/Xcode/DerivedData -name "Tokenomics.app" \
        -path "*/Release/*" 2>/dev/null | head -1 || true)
    if [ -z "$APP_BUNDLE" ]; then
        APP_BUNDLE=$(find ~/Library/Developer/Xcode/DerivedData -name "Tokenomics.app" \
            2>/dev/null | head -1 || true)
    fi
fi

if [ -z "$APP_BUNDLE" ] || [ ! -d "$APP_BUNDLE" ]; then
    echo "ERROR: Could not find Tokenomics.app. Pass the path as an argument:"
    echo "  $0 /path/to/Tokenomics.app"
    exit 1
fi

echo "[check-embedded-node] Checking: ${APP_BUNDLE}"
echo ""

# ── Check binary presence ────────────────────────────────────────────────────

NODE_BIN="${APP_BUNDLE}/Contents/Resources/embedded-node/bin/node"
NPM_BIN="${APP_BUNDLE}/Contents/Resources/embedded-node/bin/npm"

check_exists() {
    local path="$1"
    local label="$2"
    if [ -f "$path" ]; then
        echo "  [OK] ${label} exists"
    else
        echo "  [FAIL] ${label} NOT found at: ${path}"
        FAILED=1
    fi
}

FAILED=0
check_exists "$NODE_BIN" "node binary"
check_exists "$NPM_BIN" "npm binary"

if [ "$FAILED" -eq 1 ]; then
    echo ""
    echo "FAIL: Embedded Node binaries missing. Did fetch-node.sh run during pre-build?"
    exit 1
fi

# ── Check code signature ─────────────────────────────────────────────────────

echo ""
echo "Code signature on node binary:"
codesign -dv "$NODE_BIN" 2>&1 | grep -E "(Authority|TeamIdentifier|Flags|identifier)" || true

echo ""
echo "Code signature on npm binary:"
codesign -dv "$NPM_BIN" 2>&1 | grep -E "(Authority|TeamIdentifier|Flags|identifier)" || true

# Verify the binary has a valid signature (non-zero exit = not signed)
if codesign --verify --strict "$NODE_BIN" 2>/dev/null; then
    echo ""
    echo "  [OK] node binary signature is valid"
else
    echo ""
    echo "  [FAIL] node binary signature INVALID or missing"
    echo "  This will cause Apple notarization to reject the app."
    echo "  Check the post-build codesign phase in project.yml."
    FAILED=1
fi

# ── Check hardened runtime ───────────────────────────────────────────────────

echo ""
FLAGS=$(codesign -dv "$NODE_BIN" 2>&1 | grep "flags=" || true)
if echo "$FLAGS" | grep -q "runtime"; then
    echo "  [OK] Hardened runtime enabled (required for notarization)"
else
    echo "  [FAIL] Hardened runtime NOT set. Add --options runtime to the codesign call."
    FAILED=1
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo "All checks passed. The embedded Node binary should survive Apple notarization."
    echo ""
    echo "Next: run ./scripts/distribute.sh to build, sign, notarize, and upload."
    echo "Apple's notary service is the authoritative gate — this script can't replace it."
else
    echo "One or more checks FAILED. Fix the issues above before submitting for notarization."
    exit 1
fi
