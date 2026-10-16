# Actual unprivileged identity portability repair

The [author's original record](author/README.md), [independent review](independent/review.final.md) and [archive manifest](archive_manifest.json) preserve actual files, logs, sources and identity mappings byte-for-byte. This is a test portability fix, not a production UID-helper or gameplay change.

The original hard1000 implementation failed under an actual kernel euid1001 process. The old routing test independently still failed `1001 !=1000` when replayed against the fixed helper. Both original failures and separate later replays remain labelled. The fixed author tests pass UID3/routing16 at actual1000 and1001; the reviewer independently also tested65534, with all three identities passing both suites.

1001 and65534 are real Linux user-namespace identities mapping to hostuid1000, as the retained `/proc/self/uid_map` observations disclose. They are not distinct host accounts, mocked geteuid values or fabricated PermissionError responses. In each process, chmod000 actually denies directory enumeration before the real helper preserves the original UID bytes. Zero or mismatched explicitly requested probe identities reject. Readable referenced/unreferenced/archive behavior remains tested.

The original root setgroups/setgid/setuid1000 branch and its original1000 equality assertions remain. That root branch was not executed on this unprivileged host. All original self.assert calls and the other15 routing test function AST bodies remain unchanged.

The remote workflow's visible failure was routing; Azure403 prevented retrieving its artifact. This actual reproduction proves a portability defect, not the unique remote failure cause or a newly green remote workflow. No Godot, host-worker call, mission, lease, budget or production helper changed.

The manifest maps each original path to its portable location and original SHA256/byte count. Source commands/absolute paths inside original reports remain provenance, not claims those paths exist on every checkout. [Integrity check](archive_check.json) verifies every copied byte and this README's local links. Independent acceptance is limited to this numerical-identity test adaptation and its actual permission proof.
