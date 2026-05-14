# OKAK Chat Agent Rules

- Work in this Flutter app unless the user explicitly asks for the backend.
- Answer the user in Russian, concise and practical.
- Start non-trivial work with `git status --short`. Never revert dirty changes you did not make.
- Use only real paths returned by `rg --files`, `find`, or `ls`. Never use `lib/features/shell<workspace>_shell.dart`.
- Prefer `rg`, `rg --files`, and small `sed -n` chunks. Do not dump whole large files or unbounded command output into context.
- For multi-file work, use `/slice` or the `orchestrator` agent. Split discovery, implementation, review, and verification into separate agents when the scopes are independent.
- Keep one editing owner per file group. Subagents should not overlap write scopes.
- Verify Flutter changes with `dart analyze` first, then scoped tests only when relevant.
- Keep handoffs in `OPENCODE_START.md` short: goal, dirty files, completed slice, next slice, checks run.

## gstack

Use the `/browse` skill from gstack for all web browsing. Never use `mcp__claude-in-chrome__*` tools.

OpenCode loads gstack from `~/.claude/skills/gstack` when external Claude skills are enabled. The same gstack skills are exposed here as OpenCode slash-command wrappers:

`/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/design-consultation`, `/design-shotgun`, `/design-html`, `/review`, `/ship`, `/land-and-deploy`, `/canary`, `/benchmark`, `/browse`, `/connect-chrome`, `/qa`, `/qa-only`, `/design-review`, `/setup-browser-cookies`, `/setup-deploy`, `/setup-gbrain`, `/retro`, `/investigate`, `/document-release`, `/document-generate`, `/codex`, `/cso`, `/autoplan`, `/plan-devex-review`, `/devex-review`, `/careful`, `/freeze`, `/guard`, `/unfreeze`, `/gstack-upgrade`, `/learn`, `/sync-gbrain`.

Prefer the lightweight local `/slice` workflow for normal OKAK Chat implementation. Use gstack when the user explicitly asks for a gstack skill, wants broad review, design critique, shipping workflow, browsing, or an autoplan-style multi-agent pass.
