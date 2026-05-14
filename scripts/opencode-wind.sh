#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${WINDSURF_API_KEY:-}" ]]; then
  echo "WINDSURF_API_KEY is not set. Export it first, then rerun this script." >&2
  exit 1
fi

unset OPENCODE_DISABLE_EXTERNAL_SKILLS
unset OPENCODE_DISABLE_CLAUDE_CODE_PROMPT
unset OPENCODE_DISABLE_CLAUDE_CODE_SKILLS

exec opencode "$@"
