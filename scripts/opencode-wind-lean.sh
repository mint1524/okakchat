#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${WINDSURF_API_KEY:-}" ]]; then
  echo "WINDSURF_API_KEY is not set. Export it first, then rerun this script." >&2
  exit 1
fi

export OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1
export OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1

exec opencode "$@"
