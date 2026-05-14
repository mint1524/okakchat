---
description: Split and execute a bounded OKAK Chat slice with subagents
agent: orchestrator
---

Use the `okak-slice` skill.

Goal: $ARGUMENTS

Continue the current dirty worktree. Do not revert changes.

Start with:

1. `git status --short`
2. `rg --files lib test .opencode | sort`
3. Read only relevant files in small chunks.

If the task touches multiple independent areas, delegate:

- `slice-explorer` for code questions.
- `slice-worker` for one disjoint edit scope at a time.
- `slice-reviewer` for diff review.
- `slice-verifier` for analyzer/tests.

Finish with changed files, verification, and next slice if any.

