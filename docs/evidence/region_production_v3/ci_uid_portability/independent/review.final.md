# Independent UID portability review — scoped ACCEPT

Reviewer `/root/v3_preflight_independent`, read-only review, 2026-10-15. Scope only two test files:

- `tests/test_forest_uid_preservation.py`: SHA256 `a1d024d75bb23870c9ea8867de1f4cefb71a6a9289b814e0302e40e90c530647`.
- `tests/test_level_design_routing.py`: SHA256 `679654722d92f3ce93a85e4c6947e6c58bbf079990d84d78e5657575024beb57`.

**ACCEPT for the demonstrated test-identity portability correction, G0/G4 process scope.** No production helper or game/native/asset/lease/budget source was changed by this reviewer. No Godot, host AI worker or remote CI execution was performed.

## Actual independent execution

The reviewer independently ran the three UID tests and sixteen routing tests successfully as actual host euid1000, actual kernel namespace euid1001, and an additional independent namespace euid65534. All six full-suite runs exit0. The extra65534 identity tests demonstrate that the implementation does not merely replace a1000 constant with a1001 constant.

The namespaces are real Linux `unshare --user --map-user=... --map-group=...` processes. Each alternate namespace maps its selected UID to host UID1000; they are **not separate host accounts**. `/proc/self/uid_map`, `/proc/self/gid_map`, `/proc/self/status` UID/GID fields, actual returned euid and child results are recorded. No identity syscall, subprocess transport, filesystem or PermissionError was mocked.

For each identity an independently authored probe ran all three actual temporary-filesystem cases: chmod000 directory enumeration genuinely raises PermissionError before the real production helper runs; unknown enumeration preserves exact referenced UID bytes and does not archive/delete; readable referenced bytes are kept; readable unreferenced bytes are archived byte-for-byte before removal. Each identity also executed real subprocess negative cases with expected UID0 and a mismatched nonzero expected UID; all refuse. The expected identity comes from the actual calling process, is passed explicitly to the child, and the child independently checks real kernel euid equality and nonzero status. Identity is not trusted from returned fixture metadata.

## Before/after and preserved assertions

The exact archived old UID suite was independently replayed under actual namespace1001: all three cases refuse on the old fixed-euid1000 assertion. The exact archived old routing source was also replayed against the current fixed helper under1001: sixteen tests run, with exactly one failure on its own `1001 != 1000` assertion. These are newly executed local archived-source reproductions, **not historical remote CI logs**; original source bytes and SHA are recorded. The virtual tracked `__file__` is used solely to retain original import/ROOT semantics while compiling exact archived bytes.

Independent AST comparison confirms all original `self.assert...` call subtrees remain, including the root-only equality1000 assertion; fifteen of sixteen routing test methods are AST-identical. Only the identity-specific test method changes in each suite, adding actual-caller equality for existing nonroot processes and a nonzero requirement. The original root branch retains setgroups/setgid/setuid1000 and the old equality assertion. This host is nonroot; **the root preexec branch was statically preserved but was not exercised**. The same actual chmod-denial, UID-byte, source-reference and archive assertions remain in place; no skips or relaxed permission acceptance were introduced.

## Boundaries

This proves the old fixed1000 assumption is a real portability defect and that the new tests work for the tested real identities. Azure artifact retrieval403 and the remote job's generic routes failure do not identify every remote cause. This review **does not claim this was the sole CI failure cause, that CI is now green, or that a failed remote job was rerun successfully**. User-namespace demonstrations do not establish all OS/container/root/capability configurations. Required native/Forest completion, actual gameplay, device and user acceptance remain outside this review.

All raw independent logs, scripts, exact SHA/AST preservation results and original-source reproductions are retained in this directory. Production source bytes remained unchanged throughout review.
