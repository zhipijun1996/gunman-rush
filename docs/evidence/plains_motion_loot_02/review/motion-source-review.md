# PLAINS-MOTION-LOOT-02 independent body-motion source review

**ACCEPT — source and observed automated evidence only.** Reviewer `/root/guard_review_recovery` did not write the reviewed motion, rigs, hosts, corpse logic or motion tests. No Godot/rendering/native checks ran in this review; only `/tmp` artifacts were written. Exact target is **a5ff2ccb9bd59efc79eb5fb1bc2b6e59de0f4249**. Fifteen reviewed source/test files match that commit, and their bytes also match the actual996 recording source;37 independent source-integrity checks passed. The paired JSON records every SHA. No current production-path blocking regression was found.

## Clock and state ownership

The real EnemyPresentationLifecycle rejects pause, invalid/out-of-tree state, nonfinite and nonpositive delta before calling the observer. It owns one motion and one accepted-hit sample advance. Position/phase data come from the actor's accepted read-only snapshot. Repeated revision refresh0 changes no observer clock/inertia; draws only resynchronize a new epoch and cannot consume ordinary displacement. Pure-body viewport culling does not skip lifecycle observation.

Accepted world displacement drives gait/travel; filtered acceleration produces bounded start/brake drive. Body_follow and appendage_follow form two ordered low-pass stages; the latter carries the intermediate delay into head motion, while the mass itself uses drive/travel/stride joints. A >=48wu discontinuity rebases follow/drive without inventing stride. A new health epoch clears all clocks/follow values. Terminal observers stop live advancement; corpse progress has a separate owner. No AI duration, HP, attack behavior, definition or Motor source was changed by this workline's body code; the Actor diff only changes audio dispatch.

## Seven structures

| Species | Source behavior reviewed |
| --- | --- |
| Patrol | Opposed support/swing legs; upper chest breathing/weight compression; head-first turn and lag; knee/head hurt stumble. Final death now lowers chest and then head onto support. |
| Charger | Foreleg loading, horn/shell pitch, restrained ribcage breath, slower mass/head response and local shell shock. |
| Diver | Both actual legacy/Underworld sources retain separate wing/rotor/thorax/abdomen/foot joints; all four live/remains host bob reads consistently return0 for diver. Wing phase drives mass and later feet; accepted attack fold/brake inputs remain authoritative. |
| Hopper | Ground-only weight transfer, large hind chain and air distinction, belly breathing/contraction, delayed head and phased leg/head collapse. |
| Seed sentry | Sac inflation/retraction, independently aimed nozzle, chamber pitch and leaves rotating around carried hinges; support toes remain nearly fixed. |
| Fan sentry | Wing downstroke carries copper body, then delayed feet; load opens two wings while stabilizing body, recoil and hurt are local. Death becomes asymmetric and stops reading its running death/live clock at completed contact. |
| Root bell | Root-anchored lower stem carries elbow, then upper stem carries hanger/leaf pivots; bell and leaves add delayed movement. Accepted hurt and pulse phases bend the structure rather than shifting a complete image. |

These are spatial joints/masks and differing phase responses, not a common translation of every visible point. The added code does not generate auxiliary intent/path/HP lines or decide damage.

## Hurt, terminal handoff and resting corpses

Six articulated bodies preserve captured drive/hurt/turn/air anatomy at death0. Their death1 output uses anatomical targets only, so changing clock/stride/drive/hurt/attack inputs cannot keep a settled corpse breathing. The fan's advancing death-age branch explicitly returns before its clocks at completed contact. Final rig shaders have no TIME-driven channel. The independent corpse owner applies a bounded local hold/contact impulse, follows real weak support and gates event/epoch starts; persistent charger/diver retain support-local final poses, other types hold then fade after settling. Removing support releases a final pose to fall without replaying death.

Diver uses the original separate authoredD1-D4 death owner, including real support/landing and final wing pose; this review does not turn its terminal static bypass into proof of exact deformed live-vertex/D1 equality.

I read the actual native09 **346/0** clean log and its **84/0 motion** artifact. It uses real Factory/Actor snapshots, six opaque source skins and both real diver skins with explicit scripted position inputs. Observed examples include start/stop drive +.4393/-.4374, planted idle foot movement below.05wu, nonrigid upper motion, epoch reset, paused-owner rejection, teleport rebase, death0/1 checks and patrol opaque head at **-.216192wu** within the1wu support band. These were not newly executed or reassigned to a later source. Their finite probes do not certify full normal-size pixels, every contour or every terrain phase.

## Explicit API boundary and remaining evidence

A direct internal call to PlainsMotion02.advance(actor,0) still updates private _last_position before returning. This ordering predates2ac. The real lifecycle blocks zero/nonfinite/paused calls before reaching it, and refresh0 never calls observer.advance, so it is not a current regression. The native zero-tick assertion verifies clocks/inertia, not every private baseline. Future consumers must keep the owner gate rather than assume the internal method is an unrestricted read-only API.

The source review and original automated evidence support this limited acceptance. Full167/affected artifacts remain a separate pending audit. G1–G5, formal GUI/consumer coverage, subjective visual/audio quality, player approval, balance and real devices remain unverified. The actual996 video provenance stays unchanged, even though these specific motion bytes are identical in a5ff.
