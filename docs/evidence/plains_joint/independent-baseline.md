# Independent baseline review — joint-place synthesis

Reviewer: delegated `joint_review`, read-only production scope. Baseline runtime is `ef6a8b4f1d06406b6b5f0a3db658902c15c1084e` (PR84), repository starting HEAD `f8dead080f2195c5c3b332966ec76fe4ba2181e3`. Read AGENTS, current-state/handoff current sections, gameplay-reviewer and scene-composer Skills, and `docs/quality/plains_places.md`. No engine, artwork, code or tests authored by this reviewer.

Actually opened four unmodified 1280×720 native frames through view_image. These are video frames, not exact physics ticks:

| Original | Seed / frame | SHA256 |
| --- | --- | --- |
| `../plains_places/frames/round02_court_entry.png` | plains-places-first-01 / 120 | 21ecc8a086135bfa4641e117d658f3f239f097f7abef72a857d10a3cea82db1d |
| `../plains_places/frames/round02_meadow.png` | plains-places-first-01 / 480 | f81317169539cc615fd553ea8a0aa1256a8d53c080dec8507d1c89a0060470b1 |
| `../plains_places/frames/round02_connection.png` | plains-places-first-01 / 600 | 1d711bda9a800c997c6669ba45b9adbbda5d77e62b17b2073ff56147a57e0c11 |
| `../plains_places/frames/seed_01_entry.png` | places-contract-01 / 120 | b677885e98111d8730b29670851f0006029b8babb4b38fcf3f1cd1dc356d62d0 |

## Pixel findings and consequential experiments

1. **Actor/root density at entry.** In Seed01 frame120, girl at approximately x295,y410 visually fuses with the pale tree roots and densely hatched golden grass. In meadow frame480 she is clear against the quieter air at x735,y400, so the evidence supports a local root/arrival composition problem, not a claim that the character is universally unreadable. Joint synthesis should make the landing/entry viewing envelope and actual rooted-object placement constrain one another. Merely recording a keep-clear rectangle without changing placements is not improvement.
2. **Repeated landmass structure dominates.** Connection frame600 shows opposing detached banks with the same stepped right shoulder and similar downward diagonal planes. Court120 is a genuine coherent stepped body, but the repeated exposed float-body silhouette and golden surface dominate the experience. More permutations of these fixed bodies do not establish co-designed spaces. A meaningful candidate must change actual terrain envelope and associated play route / viewing composition together, not only names, plan metadata or the location of the same tree.
3. **Layers share contours and surface density.** Meadow480 has foreground platform and background terrace edges at similar levels, with highly legible stepped/background structures. Connection600 has an attractive quiet sky around the airborne girl, but both banks compete through similarly sharp grass and pale rock. A new plan should actually preserve some clear sky/low-frequency region at required actions while placing enclosing middle layers relative to that same space and camera. More backdrop instances alone cannot demonstrate depth or attraction.

These are AI professional observations, not user preference or market facts. The court has improved coherent volume and the airborne connection has useful negative space; retaining those strengths is appropriate. Existing P1 is a candidate preference, not final art authority.

## Admission boundary

No new candidate exists in this review. `UNVERIFIED` for new joint production. Reject a success claim based solely on compiler correctness, numeric diversity, extra fields, or more fixed island permutations. New native source-bound frames and actual route observations must show whether the method changes both geometry and image. Do not require arbitrary polygon detail, more texture, or removal of rectangular collision. Complete movie playback, listening, actual manual operation, physical devices and player preference were not performed here.
