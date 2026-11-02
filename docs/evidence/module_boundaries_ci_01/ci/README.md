# Module CI routing candidate

Author write set is only config/production_impact.json, tools/production_plan.py, tests/test_production_plan.py, and the four added media-gate lines in .github/workflows/production.yml. Root's concurrent production changes are excluded from candidate.patch.

- Ordinary documentation: docs + structure + quality, all pure Python. Style/Bible, quality and world-design documents add their own existing validators. Full docs remains a manual profile.
- game/application, player, combat, loadout, economy, rewards, progression, enemies, bosses, world, presentation and platform: finite existing module checks plus shared runtime contracts; integration adds the explicit real downstream consumers listed in policy. This includes the App/Forest/EnemyActor forest Bible consumers and enemy-drop consumers identified in review.
- A test/tool command entry uses the existing Harness argv directly. Known fixture families use a small set of module path rules. No check_owners, AST import registry, new runner or broad cache-input dependency inference remains.
- Unknown paths, shared physical/resource/save/RNG/composition contracts, global validators and build/toolchain changes retain full171. Exact config exceptions cannot expand through a policy glob. Existing specifically pinned presentation rules retain their conservative full-integration behavior.
- production.yml already executes selected_commands or exact full_lanes and materializes their inputs. Only a verified stdlib set (baseline3 plus harness-tests) skips the existing media install. Unknown or other checks retain installation; engine/web/full lane and deployment routing are unchanged.

The current registry remains byte-identical:218 registered checks,171 default full,30 legacy manual entries, unchanged timeouts/commands/markers. Original historical144…185 lane assertions still execute against pinned historical projections; full-trigger fixtures now use project.godot rather than incorrectly requiring the newly scoped App path to remain full.

Evidence: candidate-review.json binds final four SHAs; original33-disposition.json gives each previous blanket docs check its current baseline/domain/direct-entry/fallback responsibility; example-plans.json gives actual plan output. Final planner46/0 (0.161s), original Harness91/0 (22.679s), and post-media-gate original workflow tests2/0. No engine, remote CI, application or deployment acceptance is claimed. Current source-authority binding drift and historical Bible30s completion failure remain separate unresolved gates.

Superseded actual-consumer-map.json and build_policy.py are retained external rejected design evidence only. They are not shipped, executed by the planner, or current dependency authority. This candidate is frozen for non-author review; no stage/commit by this author.
