#!/bin/bash
set -euo pipefail
APP_SUPPORT="$HOME/Library/Application Support/PomodoroScreen"
DB_PATH="$APP_SUPPORT/statistics.db"
if [ ! -f "$DB_PATH" ]; then
  echo "Database not found: $DB_PATH" >&2
  exit 1
fi
FROM_TS=${1:-$(date -v-1d +%s)}
TO_TS=${2:-$(date +%s)}
# Type counts
sqlite3 -csv "$DB_PATH" "SELECT event_type, COUNT(*) AS cnt FROM statistics_events WHERE timestamp >= $FROM_TS AND timestamp < $TO_TS GROUP BY event_type ORDER BY cnt DESC;" | awk -F, 'BEGIN{printf("\n== Event Type Counts ==\n")} {printf("%-28s %s\n", $1, $2)}'
# Hourly histogram
sqlite3 -csv "$DB_PATH" "SELECT datetime((timestamp/3600)*3600, 'unixepoch', 'localtime') AS hour_bucket, COUNT(*) FROM statistics_events WHERE timestamp >= $FROM_TS AND timestamp < $TO_TS GROUP BY (timestamp/3600) ORDER BY hour_bucket;" | awk -F, 'BEGIN{printf("\n== Hourly Histogram ==\n")} {printf("%s  %s\n", $1, $2)}'
# Hourly by type (top 5 types by count)
TOP_TYPES=$(sqlite3 -csv "$DB_PATH" "SELECT event_type FROM statistics_events WHERE timestamp >= $FROM_TS AND timestamp < $TO_TS GROUP BY event_type ORDER BY COUNT(*) DESC LIMIT 5;")
echo "\n== Hourly by Type (Top 5) =="
IFS=$'\n'
for t in $TOP_TYPES; do
  echo "-- $t --"
  sqlite3 -csv "$DB_PATH" "SELECT datetime((timestamp/3600)*3600, 'unixepoch', 'localtime') AS hour_bucket, COUNT(*) FROM statistics_events WHERE timestamp >= $FROM_TS AND timestamp < $TO_TS AND event_type='$t' GROUP BY (timestamp/3600) ORDER BY hour_bucket;" | awk -F, '{printf("%s  %s\n", $1, $2)}'
  echo
done
