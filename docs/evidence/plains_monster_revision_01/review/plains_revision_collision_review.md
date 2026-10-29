# Plains revision · collider design/code review

Independent reviewer `/root/revision_r3_review`, read-only, no engine execution. Reviewed current dirty delta after `49176c04589c9b156b6a9e34543ff25eb01d2022` at hashes below; future exact source/physics/capture results are separate.

**ACCEPT the declared narrow collider adjustment intent; runtime fit remains UNVERIFIED pending real consumers.** This is not an overall monster acceptance.

Actual comparison02 showed the previous fan28×32 rectangle larger than the central abdomen, and charger32wu collision height exceeding the new whole visible30.375wu silhouette. Root's final proposal uses fan22×18, not the earlier14×18: the approx14wu abdomen sits approx3.3wu off the Actor x center and mirrors with facing, so22wu protects that core plus small root margin while leaving the outer broad wing surfaces outside a single solid box. Actor/muzzle/save coordinates stay at their existing center. The scope explicitly discloses this conservative center choice and does not pretend every empty rectangle corner equals painted body. Charger28×28 removes the old excessive top extent without turning the ivory horn/whole40.5wu envelope into one solid rectangle. Versions both2→3 reflect changed definitions.

The visual foot is Actor position+Definition half-height and factory/placement paths consume Definition; changing collision dimensions therefore changes actual contact/body anchoring and any behavior predicates reading that dimension. It must not be described as literally identical gameplay geometry. Root scope correctly lists this as an explicit authorized body-fit change; HP, damage and phase durations are unchanged in the finite delta.

Required follow-up is original real consumers plus useful physical counterexamples at left/right abdomen/core, outer fan wing beyond its new body rectangle, close player contact and terminal support. Actual movie must retain unchanged player/reference scale and show grounded versus aerial placement. Neutral alpha/body UV maps alone cannot establish those behaviors or dynamic silhouette fit. No instruction here lowers old test budgets or accepts a new test which only repeats Definition metadata.

```json
{
  "resources/enemies/plains_charger.tres": "39513bce9f2d604514a88838d733db24b723ce965402ce5579e8260f5a83a232",
  "resources/enemies/plains_fan_sentry.tres": "46d9b74618f024666788bd8daf48c25efbe62e41aed16cc94adfa74fa66c94c4",
  "docs/worklines/plains_monster_revision_01/scope.md": "409eadbe5f6702c438646162a8a350909f464c6957edb1b1a7dc0693a1d9f709"
}
```

## Actual support failure, corrected sole probe and physical counterexamples

Root froze clean `7edda9f5f2a20c5406391ff3f7edebbeb2322047`. The shared Motor change is confined to `move_attack(require_floor=true)`: require actual RectangleShape2D; derive leading x=half.x+1 and sole y=half.y; keep original ten-unit ray from sole-2 to sole+8, layer1 and owner exclusion, refusal stopping velocity and unchanged move_and_collide movement. Only ChargerAttackStrategy passes true among actual production callers; all existing moth, forest, hopper, diver and return callers use false and bypass this change. `_hit_landing_supported` is untouched.

An earlier proposed half.y+2 variant would retain the old28×32 ray offsets but still started at a floor boundary for an exactly supported resized body. Root actually ran it:339/2, both left/right real supported charge checks failed; the original log remainsFAIL. The final sole-relative variant intentionally shifts the ray upward and is **not byte-equivalent to the old ray for28×32 consumers**. This repairs the boundary miss rather than concealing it with float tolerances or weakening support requirements.

I read the complete strict native logs: initial physical volume337/0, real failed support339/2, and corrected340/0 with normal audio drain and no script/shader/ObjectDB/resource/RID failure. The fixture gets the actual PlayerProjectile radius3 and uses true PhysicsShapeQuery cast_motion against the instantiated collider from both horizontal sides. Core sweeps hit; sweeps at the former oversized top clear for fan ground/air and charger. Two actual supported move_attack calls each travel1wu; a600wu unsupported destination refuses without changing position. The latter is a declared direct-physics geometry fixture, not natural AI aiming, actual FrameDamagePolicy damage or a complete small-step edge traversal. No hit/miss threshold or original budget was lowered.

**ACCEPT this inspected collider/motor implementation and the meaningful limited physics proof.** This removes the found core-size/top-edge and supported-charge failures in the tested consumers. It does not sign every wing/body animated pixel, natural contact balance or the new exact-source movie; these require the final capture. Logs are implementation-run proof read by this independent reviewer; the standalone raw logs do not themselves contain a complete exact-head snapshot, so frozen Harness/capture receipts retain their separate role.

```json
{
  "scripts/enemies/enemy_motor.gd": "f5c95f122662e4d52689d4c8513948bc57a77035e2f1c52619b6f4a6be20b6df",
  "tests/plains_revision_01_runner.gd": "e34c1a20ba79646266e174ad0e00a94d01679cdacba9e92d64889dfd133d8d21",
  "resources/enemies/plains_charger.tres": "39513bce9f2d604514a88838d733db24b723ce965402ce5579e8260f5a83a232",
  "resources/enemies/plains_fan_sentry.tres": "46d9b74618f024666788bd8daf48c25efbe62e41aed16cc94adfa74fa66c94c4",
  "build/plains-revision-collider-sweeps-01.log": "a461483ddfa5073994f565edd79355ea1b121c3c1d806a3c129e67df2a880529",
  "build/plains-revision-collider-sweeps-02.log": "84148233cf6c5c1cf82408e7afd9b105b496f54995f98abd55d045482efa622d",
  "build/plains-revision-collider-sweeps-03.log": "632179b6b30f8de60a22c4d710ad76b70333df9161887be18fc68750e91f2154"
}
```
