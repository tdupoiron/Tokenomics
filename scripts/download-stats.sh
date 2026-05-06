#!/usr/bin/env bash
# download-stats.sh — print rolling Tokenomics download totals.
#
# Source of truth: Cloudflare D1 (database "tokenomics-downloads") populated
# by the Pages Function at trytokenomics-site/functions/download/[[path]].ts.
# All UTC timestamps are converted to Mountain Time (DST-aware, America/Denver).
#
# Requirements:
#   - wrangler CLI (`npm install -g wrangler` or `brew install cloudflare-wrangler2`)
#   - python3 (ships with macOS)
#
# Usage:
#   ./scripts/download-stats.sh                # all-time summary
#   ./scripts/download-stats.sh --by-version   # totals per version
#   ./scripts/download-stats.sh --by-channel   # web vs brew vs other
#   ./scripts/download-stats.sh --by-day 30    # last N days, grouped by Mountain day
#   ./scripts/download-stats.sh --by-country   # ISO-2 country breakdown
#   ./scripts/download-stats.sh --raw "<SQL>"  # arbitrary SQL

set -euo pipefail

SITE_DIR="${SITE_DIR:-$HOME/projects/trytokenomics-site}"
DB_NAME="tokenomics-downloads"
TZ_NAME="America/Denver"

if [[ ! -d "$SITE_DIR" ]]; then
  echo "error: site repo not found at $SITE_DIR" >&2
  echo "set SITE_DIR=/path/to/trytokenomics-site to override" >&2
  exit 1
fi

# Run a SQL query and pretty-print results with timestamps converted to MT.
# Usage: run_query "<sql>"
run_query() {
  local sql="$1"
  (cd "$SITE_DIR" && wrangler d1 execute "$DB_NAME" --remote --command "$sql" --json) \
    | TZ_NAME="$TZ_NAME" python3 "$(dirname "$0")/_format_stats.py" table
}

# Fetch all download rows and bucket by Mountain Time day client-side.
# This is correct across midnight UTC (which would split a single MT day
# into two UTC days under naive substr-based grouping).
run_by_day() {
  local days="$1"
  local sql="SELECT ts FROM downloads WHERE ts >= datetime('now', '-${days} days') ORDER BY ts;"
  (cd "$SITE_DIR" && wrangler d1 execute "$DB_NAME" --remote --command "$sql" --json) \
    | TZ_NAME="$TZ_NAME" python3 "$(dirname "$0")/_format_stats.py" by-day
}

cmd="${1:-summary}"

case "$cmd" in
  summary)
    run_query "
      SELECT
        COUNT(*)                AS total_downloads,
        COUNT(DISTINCT version) AS versions_downloaded,
        COUNT(DISTINCT country) AS countries_reached,
        MIN(ts)                 AS first_download,
        MAX(ts)                 AS latest_download
      FROM downloads;
    "
    ;;
  --by-version)
    run_query "
      SELECT version, COUNT(*) AS downloads
      FROM downloads
      GROUP BY version
      ORDER BY downloads DESC;
    "
    ;;
  --by-channel)
    run_query "
      SELECT channel, COUNT(*) AS downloads
      FROM downloads
      GROUP BY channel
      ORDER BY downloads DESC;
    "
    ;;
  --by-day)
    run_by_day "${2:-30}"
    ;;
  --by-country)
    run_query "
      SELECT country, COUNT(*) AS downloads
      FROM downloads
      GROUP BY country
      ORDER BY downloads DESC
      LIMIT 25;
    "
    ;;
  --raw)
    run_query "${2:?missing SQL}"
    ;;
  -h|--help|help)
    sed -n '2,21p' "$0"
    ;;
  *)
    echo "unknown command: $cmd (try --help)" >&2
    exit 1
    ;;
esac
