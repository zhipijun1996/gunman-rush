# No-deployment merge constraint audit

**Recommend the proposed explicit per-commit opt-out, limited to two existing conditions.** Current origin/main is30e36c9abe223f26e666ceaf796e3fe9cb58e10f; worktree base is9ba7d4b64b939f80168a3d7d1ef08fd32a5b6be8. environment.yml currently equals main and automatically stages/deploys Pages on every main push. That conflicts with the latest authorized follow-up:0.4.1, complete start-clock-gate integration, minimal CI input reuse and eventual verified merge are authorized; website deployment is excluded and ordinary departure stays unchanged.

In both the existing `web` upload-pages-artifact step condition and `deploy_web` job condition, change only the main-push clause to:

```text
(github.event_name == 'push' && github.ref == 'refs/heads/main' && !contains(github.event.head_commit.message, '[skip-playtest]'))
```

Keep the existing manual deploy and feature publish clauses byte-for-byte. Keep all full CI, build, normal Web artifact upload, metadata/PCK verification, dependencies, budgets and concurrency. `verify_public` already needs deploy_web and will naturally skip with it; no extra condition is necessary. The separate prepared-playtest deployment is manual-only and needs no change.

The final ordinary merge commit must actually include `[skip-playtest]`; verify its final message before relying on the guard. This opt-out affects that main commit only. Future unmarked main commits retain current publishing behavior; manual deployment remains available. Do not use `[skip ci]`, disable a workflow or change future default deployment policy.

Existing `CIWorkflowCoverageTests` contains2 methods preserving full-check ownership and exact Web output verification, but has no publication truth table. Append focused checks of the actual two conditions: marked main skips; unmarked main publishes; marked main with publish marker still skips; manual true publishes even with marker; manual false skips; legacy feature publish remains unchanged. Parse YAML and reverse only the two additions to recover the original workflow bytes exactly. Run bounded pure workflow/selector tests and ordinary final quality checks; no deployment is needed to validate this guard.

After the authorized verified merge, inspect main commit/message and the actual workflow run: full CI/build should proceed, Pages upload/deploy_web/verify_public should be skipped. No website action or fresh public URL is implied.

Separate existing CI concern: environment.yml still floats Python3.12 while the original phase guard compares the entire toolchain. That can recreate PR130's patch mismatch and should be handled within the independently scoped CI work, without expanding this deployment opt-out.

This is a read-only proposal audit, not acceptance of a future patch or integration. No repository edits, tests, Godot/browser, deployment or PR130 CI action occurred. The JSON companion binds inspected source hashes and concrete validation cases.
