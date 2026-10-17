#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bundle="$(pwd)/build/linux/x64/release/bundle"
mkdir -p dist
# Verify the packaged release libraries, not the debug libraries from test env.
unset UST_CORE_LIBRARY UST_PDFIUM_LIBRARY UST_OCR_TESSDATA
export GDK_BACKEND=x11
"$bundle/universal_studio_toolkit" > /tmp/ust-linux-startup.log 2>&1 &
app_pid=$!
cleanup() {
  if kill -0 "$app_pid" 2>/dev/null; then kill "$app_pid"; fi
  wait "$app_pid" 2>/dev/null || true
}
trap cleanup EXIT
sleep 8
if ! kill -0 "$app_pid" 2>/dev/null; then
  echo 'Packaged application exited during startup.' >&2
  cat /tmp/ust-linux-startup.log >&2
  exit 1
fi
# The display belongs only to this xvfb-run invocation.
xwininfo -root -tree > /tmp/ust-linux-windows.txt
if ! grep -Fq '"Universal Studio Toolkit"' /tmp/ust-linux-windows.txt; then
  echo 'Packaged application did not create its window.' >&2
  cat /tmp/ust-linux-startup.log >&2
  exit 1
fi
printf '%s\n' '{"startup_survived_seconds":8,"window_created":true,"clean_system_verified":false,"interactive_workflow_verified":false}' > dist/linux-startup-smoke.json
