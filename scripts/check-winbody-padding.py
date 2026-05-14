#!/usr/bin/env python3
"""
Verifies that every chrome container wraps step view content with the SAME
winbody inset, so the content area sits in identical position regardless
of which step is active. Catches drift like the chooser silently using
s7 (48pt) horizontal padding while every other step used 40pt literal.

Canonical spec from mockup HTML .winbody:
  padding: 32px 40px 28px;  (top / horizontal / bottom)

Scope:
  - ConnectorView.swift   — production routing for all step views
  - ConnectorContainer.swift — top-level container (welcome / chooser / connector)
  - WindowChromePreview.swift — preview-only chrome wrapper
  - ProviderChooserView.swift — chooser preview block (mirrors ConnectorContainer)

A "winbody block" is identified by a comment containing "winbody" on the
same line as "padding", followed by .padding(.top/.horizontal/.bottom)
modifiers within the next 5 lines. Each modifier value is resolved against
the 8pt Tokens.Spacing scale (s1=4 … s9=96) plus optional `+N` / `-N`.

Exits 0 when all winbody blocks match canonical 32/40/28, 1 otherwise.
"""

import re
import sys
from pathlib import Path
from typing import Optional

REPO_ROOT = Path(__file__).resolve().parent.parent
TARGET_DIR = REPO_ROOT / "Tokenomics" / "Views"

CANONICAL_TOP = 32
CANONICAL_HORIZONTAL = 40
CANONICAL_BOTTOM = 28

# Tokens.Spacing.sN → point value (8pt grid)
SPACING_TOKENS = {
    "s1": 4, "s2": 8, "s3": 12, "s4": 16, "s5": 24,
    "s6": 32, "s7": 48, "s8": 64, "s9": 96,
}

PADDING_RE = re.compile(r'\.padding\(\.(top|horizontal|bottom),\s*([^)]+)\)')
TOKEN_RE = re.compile(r'^Tokens\.Spacing\.(s\d)(?:\s*([+\-])\s*(\d+))?$')


def resolve(expr: str) -> Optional[int]:
    """Resolve a padding expression to a point value, or None if unparseable."""
    expr = expr.strip()
    m = TOKEN_RE.match(expr)
    if m:
        base = SPACING_TOKENS.get(m.group(1))
        if base is None:
            return None
        if m.group(2) and m.group(3):
            offset = int(m.group(3))
            return base + offset if m.group(2) == '+' else base - offset
        return base
    if expr.isdigit():
        return int(expr)
    return None


def find_winbody_blocks(file_path: Path):
    """Yield (line_no, top, horizontal, bottom) for each winbody-annotated block."""
    lines = file_path.read_text().split('\n')
    i = 0
    while i < len(lines):
        line = lines[i].lower()
        if 'winbody' in line and 'padding' in line:
            top = horizontal = bottom = None
            j = i + 1
            # Capture .padding(.top/.horizontal/.bottom, ...) within next 5 lines
            while j < min(i + 6, len(lines)):
                m = PADDING_RE.search(lines[j])
                if m:
                    val = resolve(m.group(2))
                    if m.group(1) == 'top':
                        top = val
                    elif m.group(1) == 'horizontal':
                        horizontal = val
                    elif m.group(1) == 'bottom':
                        bottom = val
                j += 1
            if any(v is not None for v in (top, horizontal, bottom)):
                yield (i + 1, top, horizontal, bottom)
            i = j
        else:
            i += 1


def main() -> int:
    print(f'Canonical winbody: top={CANONICAL_TOP}pt · horizontal={CANONICAL_HORIZONTAL}pt · bottom={CANONICAL_BOTTOM}pt\n')
    failures = 0
    found = 0
    for swift_file in sorted(TARGET_DIR.rglob('*.swift')):
        for line_no, top, horizontal, bottom in find_winbody_blocks(swift_file):
            found += 1
            rel = swift_file.relative_to(REPO_ROOT)
            mismatch = []
            if top != CANONICAL_TOP:
                mismatch.append(f'top={top}pt (expected {CANONICAL_TOP}pt)')
            if horizontal != CANONICAL_HORIZONTAL:
                mismatch.append(f'horizontal={horizontal}pt (expected {CANONICAL_HORIZONTAL}pt)')
            if bottom != CANONICAL_BOTTOM:
                mismatch.append(f'bottom={bottom}pt (expected {CANONICAL_BOTTOM}pt)')
            if mismatch:
                failures += 1
                print(f'❌ {rel}:{line_no} — {", ".join(mismatch)}', file=sys.stderr)
            else:
                print(f'✓ {rel}:{line_no} — top={top} · horizontal={horizontal} · bottom={bottom}')

    if found == 0:
        print('No winbody-annotated padding blocks found — script may need updating.', file=sys.stderr)
        return 1
    if failures:
        print(f'\n{failures} winbody block(s) deviate from canonical 32/40/28.', file=sys.stderr)
        return 1
    print(f'\n✓ All {found} winbody padding blocks match canonical 32/40/28.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
