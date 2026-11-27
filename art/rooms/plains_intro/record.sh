#!/usr/bin/env bash
# Keep the established room/output arguments on the current production recorder.
set -euo pipefail
exec bash "$(dirname "$0")/v29/record.sh" "$@"
