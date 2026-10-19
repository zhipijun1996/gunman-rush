# Host clock mock isolation — bounded ACCEPT

Reviewer: `/root/forest_runtime_review`, independent of this test change. Read-only review of the actual patch, archived original source, deterministic probe, and original CI failure. No production/test source was changed by the reviewer; no engine or full suite was run by the reviewer.

## Exact source and unchanged guards

Base commit: `4856d8c5d254116db9c9ecbcb38294bae4e2b5ee`.

- Original `tests/test_production_loop.py` SHA256: `29f0decbd744207da36c114d1e47ee3cbd8d50e552540d29253e76238f773b7a`.
- Patched SHA256: `cae640b00ebf2eb810d944d0f63e102aee7ca3677f3ce543f28acbb1729280a4`.

I independently read the original from the Git object and confirmed the probe's `before.py` is byte-identical. Reversing precisely the added comment and module-local `time` facade restores the entire original test file byte-for-byte. All 342 assertion-call ASTs in the file are exact and in the same traversal order. The real Git fixture, snapshot, profile command/timeout/marker/hash assertions, lease checks, setup/cleanup and all budgets are unchanged. `tools/production_loop.py` has no working-tree change. This is isolation of a global mock leak, not removal or weakening of a test.

The context managers execute left to right: first `patch.object(loop,'time',wraps=loop.time)`, then the existing `sleep` patch on that facade. Production-loop wall/monotonic queries still delegate to the real clock; its simulated host polling alone invokes `respond`. The stdlib `time` module used by subprocess stays unchanged. My earlier in-memory namespace probe independently demonstrated that old global patching redirects `subprocess.time.sleep` to `respond`, while the facade prevents that and retains the host polling callback. Static review found eight sleep-patch sites in this test file; the other seven explicitly mock `snapshot` in their enclosing functions. No second actual-snapshot counterpart was found.

## Original failure and actual deterministic evidence

The retained CI log shows a real `snapshot()` Git subprocess entering `Popen._wait(timeout)` and calling stdlib `time.sleep`; the globally patched sleep runs `respond` before `host_request.json` has been published. The failure is a missing request file, not a relaxed lease or source guard.

The supplied probe runs the complete same selected unittest with the original and patched source. The original errors once with the missing request path; the patched case passes its original assertions. Both restore stdlib sleep afterward.

An important limit: `probe.py` injects a sleep in a wrapper immediately **before** delegating a matching `subprocess.run` to `real_run`; it does not instrument `Popen._wait` itself. Thus receipt field `real_git_snapshot_waits_exercised: 1` means one matching snapshot-call scheduling injection, not proof that an actual OS wait occurred in both probe branches. The original branch is interrupted by `respond` before that delegated Git launch; the patched branch reaches the real Git call. This accurately reproduces the shared-clock namespace error deterministically, while the retained original CI traceback independently proves the real OS-wait occurrence. The probe's reused current filename also makes one old-source traceback line display current disk text; its archived source SHA and executed compiled body identify the old branch.

No need to alter the fixture, snapshot, timeout or assertions follows from this distinction. Do not describe the probe alone as two measured real OS waits.

## Evidence binding

All paths below are retained originals under `build/verification/`:

| Artifact | SHA256 |
| --- | --- |
| `host-clock-isolation01/probe.py` | `a97ed076f7046568493a6d70cc2911447ba5ff96d2865776c37c9b8be04f3e9e` |
| `host-clock-isolation01/receipt.json` | `aa9322f264bfd1b51818134be1b9d55577a5280343fe014a739cc5e7a431c52d` |
| `host-clock-isolation01/before.log` | `b36d119613d89c4e741d5d529887bbc088186745874ef48b88ab1ce1696af3fd` |
| `host-clock-isolation01/after.log` | `c454b7771faeddfe747e9ea75131da1c2e0c4247445fe1065c55315149d7a4a1` |
| `final-docs-production-loop-tests.log` | `222525dd51c1749ecc4ca90a70da801e20d43fa8e28174b8b899e24182de762b` |

The original 87-test CI run remains FAILED (one error); this review does not rewrite that result. The owner's new uninstrumented full suite was still running when this review began and is not certified here. No game behavior, native runtime, browser/device, whole CI, or release acceptance is implied. Bounded ACCEPT covers only the exact mock-isolation test patch and preservation of its original semantic guards.
