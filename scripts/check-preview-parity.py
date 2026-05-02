#!/usr/bin/env python3
"""
Verifies that paired light/dark #Preview blocks in onboarding views have
identical copy. Catches drift like the Window 4 dark headsUp truncation and
the Install Homebrew dark footnote drift caught manually during review.

Usage:  python3 scripts/check-preview-parity.py
Exits 0 when all paired previews are in sync, 1 otherwise.

Pairing rule: a #Preview whose name ends in "— light" / "(light)" is paired
with the same-base-name preview ending in "— dark" / "(dark)". Comparison
ignores the .preferredColorScheme(...) modifier and whitespace, then diffs
the remaining content.
"""

import re
import sys
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TARGET_DIR = REPO_ROOT / "Tokenomics" / "Views" / "Onboarding"

LIGHT_SUFFIX = re.compile(r"\s*[—\-(]+\s*light\s*\)?$", re.IGNORECASE)
DARK_SUFFIX = re.compile(r"\s*[—\-(]+\s*dark\s*\)?$", re.IGNORECASE)
STRING_LITERAL = re.compile(r'"(?:[^"\\]|\\.)*"')


def extract_previews(swift_file):
    """Yield (preview_name, normalized_body) for each #Preview block in the file."""
    text = swift_file.read_text()
    pos = 0
    while True:
        m = re.search(r'#Preview\("([^"]+)"\)\s*\{', text[pos:])
        if not m:
            return
        name = m.group(1)
        start = pos + m.end()  # position after the opening '{'
        depth = 1
        j = start
        while j < len(text) and depth > 0:
            ch = text[j]
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
            j += 1
        body = text[start:j - 1]
        body = re.sub(r'\.preferredColorScheme\([^)]+\)', '', body)
        body = re.sub(r'\s+', ' ', body).strip()
        yield name, body
        pos = j


def main():
    pairs = defaultdict(dict)
    for swift_file in sorted(TARGET_DIR.rglob("*.swift")):
        for name, body in extract_previews(swift_file):
            if LIGHT_SUFFIX.search(name):
                base = LIGHT_SUFFIX.sub("", name).strip()
                pairs[(swift_file.name, base)]["light"] = body
            elif DARK_SUFFIX.search(name):
                base = DARK_SUFFIX.sub("", name).strip()
                pairs[(swift_file.name, base)]["dark"] = body

    failures = 0
    unpaired = []
    for (file, base), pair in sorted(pairs.items()):
        if "light" not in pair or "dark" not in pair:
            unpaired.append((file, base, "light" if "dark" in pair else "dark"))
            continue
        if pair["light"] != pair["dark"]:
            failures += 1
            print(f'❌ {file} :: "{base}" — light/dark previews diverge', file=sys.stderr)
            light_strs = set(STRING_LITERAL.findall(pair["light"]))
            dark_strs = set(STRING_LITERAL.findall(pair["dark"]))
            for s in sorted(light_strs - dark_strs):
                print(f'   only in light: {s}', file=sys.stderr)
            for s in sorted(dark_strs - light_strs):
                print(f'   only in dark:  {s}', file=sys.stderr)

    if unpaired:
        print('\nℹ️  Previews missing a light/dark counterpart (not a failure, but worth noting):')
        for file, base, missing in unpaired:
            print(f'   {file} :: "{base}" — missing {missing} variant')

    if failures:
        print(f'\n{failures} preview pair(s) out of sync.', file=sys.stderr)
        return 1
    print(f'\n✓ All paired light/dark previews have identical copy.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
