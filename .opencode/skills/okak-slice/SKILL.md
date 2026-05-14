---
name: okak-slice
description: Token-conscious workflow for OKAK Chat Flutter slices: split work across planner, explorer, worker, reviewer, and verifier agents without bloating the primary context.
---

# OKAK Slice Workflow

Use this skill for multi-file OKAK Chat UI, Flutter, Riverpod, routing, or chat/code workspace work.

## Token Discipline

- Start from `git status --short`.
- Discover files with `rg --files`; do not invent paths.
- Read files with targeted `rg -n` and small `sed -n` chunks.
- Avoid full-file dumps for files over roughly 250 lines.
- Do not run commands that print huge global configs, full package trees, or massive agent lists.
- Summarize tool output. Keep exact snippets only when needed for a fix.

## Delegation Pattern

- Use `slice-planner` for the plan when scope is unclear.
- Use `slice-explorer` for read-only questions.
- Use one `slice-worker` per disjoint write scope.
- Use `slice-reviewer` after edits.
- Use `slice-verifier` for `dart analyze` and focused tests.

The primary agent owns integration. Subagents should not duplicate each other's work.

## OKAK Constraints

- Preserve dirty user changes.
- Do not revert files without explicit user request.
- Never use `lib/features/shell<workspace>_shell.dart`.
- Real shell files are `lib/features/shell/sidebar.dart` and `lib/features/shell/app_shell.dart`.
- Prefer existing Flutter/Riverpod patterns over new abstractions.

## Done Criteria

- Changed files are listed.
- Verification is reported.
- Remaining work is captured as a next slice, not as a broad vague todo.

