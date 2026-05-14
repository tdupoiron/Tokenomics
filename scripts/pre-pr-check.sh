#!/usr/bin/env bash
# pre-pr-check.sh — run before opening a PR or cutting a release
# Fails fast on any error. Exit code 0 = all checks passed.
#
# Flags:
#   SKIP_INTEGRATION=1  — skip the integration test phase (useful in CI without
#                         App Group entitlements where widget sync tests are skipped anyway)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
XCODEPROJ="$PROJECT_ROOT/Tokenomics.xcodeproj"
SKIP_INTEGRATION="${SKIP_INTEGRATION:-0}"

echo "==> Tokenomics pre-PR check"
echo ""

# 0a. Onboarding light/dark preview parity — catches copy drift between paired
#     #Preview blocks (e.g. dark variant with a truncated description).
echo "[1/6] Checking onboarding light/dark preview copy parity..."
python3 "$SCRIPT_DIR/check-preview-parity.py"
echo ""

# 0b. Winbody padding consistency — catches drift between chrome containers
#     (e.g. chooser using s7 48pt instead of 40pt literal).
echo "[2/6] Checking onboarding winbody padding consistency..."
python3 "$SCRIPT_DIR/check-winbody-padding.py"
echo ""

# 1. Regenerate project from project.yml to catch any drift
echo "[3/6] Regenerating Xcode project from project.yml..."
xcodegen generate --spec "$PROJECT_ROOT/project.yml" --project "$PROJECT_ROOT"
echo "      OK"
echo ""

# 2. Build (catches compilation errors before running tests)
echo "[4/6] Building Tokenomics (Debug)..."
xcodebuild build \
  -scheme Tokenomics \
  -destination 'platform=macOS' \
  -project "$XCODEPROJ" \
  -configuration Debug \
  | grep -E "^(error:|warning:|Build succeeded|Build FAILED)" || true

echo ""

# 3. Run the unit test suite
echo "[5/6] Running TokenomicsTests (unit tests)..."
set +o pipefail
xcodebuild test \
  -scheme Tokenomics \
  -destination 'platform=macOS' \
  -project "$XCODEPROJ" \
  | grep -E "(passed|failed|error:|Test session results)" | tail -20
UNIT_EXIT=${PIPESTATUS[0]}
set -o pipefail
if [ "$UNIT_EXIT" != "0" ]; then
  echo "Unit tests FAILED (xcodebuild exit $UNIT_EXIT)"
  exit 1
fi

echo ""

# 4. Run integration tests (skippable via SKIP_INTEGRATION=1)
if [ "$SKIP_INTEGRATION" = "1" ]; then
  echo "[6/6] Integration tests SKIPPED (SKIP_INTEGRATION=1)"
else
  echo "[6/6] Running TokenomicsIntegrationTests..."
  set +o pipefail
  xcodebuild test \
    -scheme TokenomicsIntegration \
    -destination 'platform=macOS' \
    -project "$XCODEPROJ" \
    | grep -E "(passed|failed|skipped|error:|Test session results)" | tail -20
  INTEGRATION_EXIT=${PIPESTATUS[0]}
  set -o pipefail
  if [ "$INTEGRATION_EXIT" != "0" ]; then
    echo "Integration tests FAILED (xcodebuild exit $INTEGRATION_EXIT)"
    exit 1
  fi
fi

echo ""
echo "==> pre-PR check complete. If you see ** TEST SUCCEEDED ** above, you're good to push."
