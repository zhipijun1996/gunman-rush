# Actual non-root UID portability repair

Remote workflow38810330857 exposes a routing failure, while Azure403 prevented retrieving its artifact. This local reproduction establishes a real portability defect; it does not claim the exact remote traceback or exclude additional remote failures.

Before editing either source, the real kernel euid1001 process ran the original UID helper suite:3tests fail on the hard euid1000 assertion. After editing only the two test files, actual euid1000 and actual euid1001 processes each pass UID3tests and routing16tests. Exact old routing source, additionally replayed against the fixed helper, still fails its own1000 assertion under actual1001; this is separately labelled rather than mistaken for a historical CI run.

This host is unprivileged euid1000 and has no sudo. The second identity uses `unshare --user --map-user=1001 --map-group=1001`: the kernel really reports1001 inside the new process; `/proc/self/uid_map` transparently records that namespace1001 maps to host1000. No euid monkeypatch or synthetic PermissionError is used. Both identities actually fail directory enumeration after chmod000 before the real production helper is called. The helper preserves exact referenced UID bytes and refrains from deleting/archiving when enumeration is unknown; readable unreferenced bytes are archived then removed normally.

PROBE receives expected UID as an explicit process argument and independently asserts actual kernel euid equals that nonzero expected value. Zero and mismatched expected identities are also refused in real subprocesses. Tests derive their expected UID from the calling process, never from fixture-reported expected values.

When the caller is root, the existing setgroups/setgid/setuid1000 preexec path and original self.assertEqual(euid,1000) assertions remain. When already non-root, the process keeps its exact actual identity, asserts that value and euid!=0, and performs the same real denied-access check. This host did not execute the root branch; no root-branch execution claim is made.

All original self.assert calls in both test files remain. The other15 routing test function AST bodies are exactly unchanged. No tests, permission denials, byte preservation or archive assertions were skipped/removed to obtain PASS. No production UID helper, Godot, host-worker request, mission or budget changed. See manifest, original sources, before/after logs and actual identity JSONs in this directory.
