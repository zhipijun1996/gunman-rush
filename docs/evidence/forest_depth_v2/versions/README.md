# Forest version compatibility checkpoint

`versions01-native76.tar.gz` preserves the actual **76 assertions / 0 failures**
Godot 4.7.2 execution, strict native exit, import/native/outer logs, receipt,
complete runtime snapshot SHA inventory, and the executed test/wrapper plus
seven version-critical production source files. `versions01-index.json` binds
all 15 members and archive bytes with SHA256. Original build evidence remains
under `build/forest_depth/snapshots/versions01/`.

This was the genuine `bee850c66b2f402d644d7daa4c13db91c8abe8f8` Git HEAD with
an explicitly recorded dirty runtime overlay in an independent snapshot. It is
not a clean committed release or the changing author worktree. Snapshot copy
and runtime source guards both passed; import/native retained their 90/90-second
caps, and total wrapper execution was 10.659 seconds. The host held the original
repository engine lock with snapshot cwd and isolated data/config/cache paths.

The run proved full v1 generator/delegate/pinned output equality for four seeds
and two maps; both legacy validators; both real legacy DemoApp stage entries,
old enemy/Boss scenes, four recorded version identities, RunManifest roundtrip
and malformed/unknown version refusal; and actual v1 hash fallback preserving
the same state object, hash, claim/open/mechanism ledgers and actor identities.
It also proved the still-unimplemented v2 map2 Queen explicitly refuses without
returning v1. These are compatibility checks, **not v2 gameplay or Boss admission**.

The tested actors had default health. The current new runner has since added
two stronger assertions that prepare a real nondefault legacy enemy health and
check the reassembled enemy retains it. That new test SHA is separately recorded
as **unexecuted**, pending the next integration snapshot. The archive retains the
old executed test bytes; the 76-pass result cannot certify those new assertions.
No original tests, production source or original harness checks were changed by
this checkpoint task. No additional native run was performed after the change.
