# PLAINS-MOTION-LOOT-02 contact / healing review

**REVISE patrol mass contact; limited healing candidate accepted for user review.** Reviewer `/root/corpse_contact_audit`, independent of all reviewed production/tests/recorder/assets. No Godot was executed and no repository production file was edited. Exact reviewed source and actual frame hashes are in the paired JSON.

## What is actually wrong

The patrol corpse in actual full02 frame321 and golden frames290/340 appears suspended: only a couple of tiny toe pixels approach the actual support, while the broad mass and head remain raised. The original native criterion `rest.y <= 0` proves only no penetration and cannot catch this failure.

The gap must not be converted into a blind8px/5wu whole-corpse offset. Actual fixed camera projects the real support18wu toscreen464; the grass artwork begins around466+. My independent pure mesh port agrees with rootactualGDScript: terminalpatrol maxopaqueY≈−0.97wu andcharger≈−0.47wu. CPU1wu raster leaves patrol only1occupiedpixel on its lowest−1.5wu row and4 on−2.5wu, while its bulk reaches32pixels only at−6.5wu. Thus mass/attachment closure, not a missing8px ownertranslation, is the problem. A gross shift would bury the toes.

Correct the patrol terminal anatomy: chest/upperbody lowers after knee release, the neck hinge travels with that mass, then the head performs its late drop. Existing smooth death progress should keep correctionzero atdeath0. Leave actualfloorowner/support/savedanchor/collision/AI/damage/timing/1wu unchanged. An upperbody lowering roughly0.10–0.13height plus a modest latehead correction is only a boundedcandidate, requiring actual rootGPU comparison.

Retain no-penetration tests and add visible support quality: actual1wu alpha/head/belly masks or a nontrivial horizontal supporting span nearfloor. One lowesttoe probe and texturebounds are insufficient.

## Other six terminal samples

I decoded and viewed each actualfull02 death+85frame: charger756,diver1192,hopper1627,sentry2062,fan2498,root2932. They show no equivalent new contact blocker in these terminal samples. My initial charger concern from the grass-gap impression is **withdrawn** after checking realplane/raster: actualcharger has9darkbodypixels atscreen463 and35at460, close tosupport464. Do not normalize all six. These stills do not approve their complete animation or every support geometry.

## Healing fix

I viewed actualhealfix02 images−3,+2,+8,+25 around realHPgrantframe374. The current visible ancestor binding shows a restrained pale mint body/arm lift at+2/+8 and returns to warmer brown by+25. HP4/5→5/5 andrestore+1 are readable. Limited ACCEPT as a candidate for user review; the old533 fullfilm no-glowfailure remains valid. No listening, device, alternate-body or userG5 approval.
