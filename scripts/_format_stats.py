#!/usr/bin/env python3
"""Render wrangler D1 --json output as a table with Mountain Time timestamps.

Reads JSON from stdin, writes a fixed-width table to stdout. Timestamps are
detected by ISO-8601-Z pattern and converted from UTC to America/Denver
(DST-aware via zoneinfo).

Modes:
    table   — render the result rows directly with timestamp conversion
    by-day  — bucket {ts} rows by Mountain-Time day, output (day, downloads)
"""
from __future__ import annotations

import json
import os
import re
import sys
from collections import Counter
from datetime import datetime
from zoneinfo import ZoneInfo

ISO_Z = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$")
TZ = ZoneInfo(os.environ.get("TZ_NAME", "America/Denver"))


def to_mt(value: object) -> str:
    """Convert a UTC ISO-Z string to a Mountain-Time formatted string. Pass through anything else."""
    if not isinstance(value, str) or not ISO_Z.match(value):
        return "" if value is None else str(value)
    dt = datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(TZ)
    # Drop subseconds; show short tz abbreviation (MST/MDT)
    return dt.strftime("%Y-%m-%d %H:%M:%S %Z")


def render_table(rows: list[dict]) -> None:
    if not rows:
        print("(no rows)")
        return
    cols = list(rows[0].keys())
    body = [[to_mt(r.get(c)) for c in cols] for r in rows]
    widths = [max(len(c), *(len(b[i]) for b in body)) for i, c in enumerate(cols)]

    def line(cells: list[str]) -> str:
        return "  ".join(s.ljust(w) for s, w in zip(cells, widths))

    print(line(cols))
    print("  ".join("-" * w for w in widths))
    for row in body:
        print(line(row))


def render_by_day(rows: list[dict]) -> None:
    """Bucket {ts} rows by Mountain-Time calendar day."""
    counter: Counter[str] = Counter()
    for r in rows:
        ts = r.get("ts")
        if isinstance(ts, str) and ISO_Z.match(ts):
            day = (
                datetime.fromisoformat(ts.replace("Z", "+00:00"))
                .astimezone(TZ)
                .strftime("%Y-%m-%d")
            )
            counter[day] += 1
    if not counter:
        print("(no rows)")
        return
    width_day = max(len("day"), max(len(d) for d in counter))
    width_count = max(len("downloads"), max(len(str(c)) for c in counter.values()))
    print(f"{'day'.ljust(width_day)}  {'downloads'.ljust(width_count)}")
    print("-" * width_day + "  " + "-" * width_count)
    for day in sorted(counter, reverse=True):
        print(f"{day.ljust(width_day)}  {str(counter[day]).ljust(width_count)}")


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "table"
    raw = sys.stdin.read()
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        # wrangler sometimes prints non-JSON banner lines first; pull out the JSON array.
        match = re.search(r"\[[\s\S]*\]\s*$", raw)
        if not match:
            sys.stderr.write("could not parse wrangler --json output\n")
            sys.stderr.write(raw)
            return 1
        data = json.loads(match.group(0))

    rows = data[0].get("results", []) if data else []

    if mode == "table":
        render_table(rows)
    elif mode == "by-day":
        render_by_day(rows)
    else:
        sys.stderr.write(f"unknown mode: {mode}\n")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
