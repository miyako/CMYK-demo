#!/usr/bin/env bash
# Runtime acceptance: stage the pinned component, run the headless scenario
# matrix, and print the report. Needs tool4d (free, headless); see README.
#
#   TOOL4D=/path/to/tool4d.app/Contents/MacOS/tool4d scripts/accept.sh [report.json]
set -euo pipefail

cd "$(dirname "$0")/.."

TOOL4D="${TOOL4D:-/Applications/tool4d/tool4d/21R4/100224/tool4d.app/Contents/MacOS/tool4d}"
REPORT="${1:-/tmp/cmyk-demo-acceptance.json}"

if [ ! -x "$TOOL4D" ]; then
  echo "tool4d not found at $TOOL4D (set TOOL4D=/path/to/tool4d)" >&2
  exit 1
fi

python3 scripts/stage_component.py
# Start each run from an empty output folder so "never overwrite" scenarios are
# deterministic.
rm -rf LabOutput

# --skip-onstartup keeps the On Startup database method (which opens the GUI
# window) out of the headless run.
"$TOOL4D" --project Project/CMYK-demo.4DProject --dataless --skip-onstartup \
  --startup-method Acceptance --user-param "$REPORT"
echo "report: $REPORT"
