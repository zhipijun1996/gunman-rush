# Exact-source CI and duplicate-event repair — proposal only

No workflow/source/Git/run mutations. Current c305 push attempt2 continues; do not cancel/rerun it. The prior PR run checked synthetic merge57e36a while run/artifact API head_sha remained c305. Existing browser verifier correctly refused that source mismatch. Do not relax its equality guards.

## Preferred minimal change: one workflow

In .github/workflows/environment.yml only:

1. All7checkout steps explicitly use ref: ${{ github.event.pull_request.head.sha || github.sha }}. This covers prepare, both core_checks matrix instances, merged-core verifier, Windows export, Web export, optional Android and public verifier's sparse checkout. Preserve existing sparse options and job guards. PR builds then export actual head commit; push/manual builds retain their original SHA. A canceled older same-branch run does not get reclassified as a new source pass.
2. The sole mistaken event-SHA consumer is prepare release-evidence. Replace --commit "$GITHUB_SHA" with --commit "$(git rev-parse HEAD)". GITHUB_SHA itself remains GitHub's reserved original event identity; do not overwrite it. tools/build.py already obtains git HEAD for source_commit, and fingerprint already copies that build-info value. No Python/browser/publish tools need changing.
3. Deduplicate push/PR by actual head repository + head.ref (ordinary events use repository/ref_name), removing event_name from the automatic namespace. Keep workflow_dispatch in a separate manual namespace so ordinary pushes cannot cancel the publish tool's explicitly bound deployment run. Include head.repo.full_name to prevent a fork's branch named main from canceling the target repository's main deploy. Proposed exact expression is in preferred.patch. Existing Pages deployment concurrency pages-playtest/cancel-in-progress:false remains unchanged.

The ignored preferred.patch/environment.yml.proposed is concrete for review, not installed. It changes only concurrency1line, exact-ref7checkout locations, and preflight1line; no native budget, original80,151registry or disjoint86/52lane changes.

## Documentation decision

Keep docs.yml default PR synthetic-merge checkout and its event-separated concurrency for this minimal patch. Its PR-only check_quality_diff uses explicit base.sha and git diff base against the checked tree to inspect changed quality declarations. Blindly sharing push/PR concurrency while keeping a push path that skips qualitydiff could cancel the only declaration check. All29docs harness checks are already within core138; full141 is core138+three Web build/bundle/cache checks. Thus keeping this separate PR merge documentation gate does not spoil exact-head artifact identity/full141 technical proof.

If eliminating the remaining cheaper docs duplicate is desired later, restrict docs push trigger to main while retaining all pull_request events, and keep PR merge checkout/base.sha qualitydiff. That is a second workflow change with different branch-trigger semantics; do not do it implicitly in the artifact repair. One can deduplicate that workflow by repository/head branch only after ensuring the PR declaration gate cannot be skipped by a surviving push run.

## Preserved tests and release safety

No existing unit asserts the old concurrency string or default PR checkout. tests/test_harness.py must retain auto-selection of workflow edits as gameplay/art/web, full-profile set equality, exact disjoint lane/source/count/log guards and original check caps. tools/test_publish_playtest.py must still refuse wrong SHA/ref/attempt, wrong or ambiguous artifact/run, missing deploy jobs, mismatched metadata/pack/digest and concurrent attempt changes. The browser verifier must keep localHEAD=requested commit=run API head=artifact API head=build-info source, clean source and unchanged artifact bytes. No published evidence gets retagged to c305 merely because its tree resembles the PR merge.

workflow_dispatch falls back to github.sha, so publisher's original head_branch/head_sha/event=workflow_dispatch identity remains correct. Deploy conditions for main/manual/explicit playtest branch, environment permissions, Pages serial concurrency, and prepared-playtest's distinct exact-helper/prepared_ref checkout are unchanged. That other deploy workflow does not trigger on PR and should not be generalized to this ref expression.

If root implements this later, minimum validation is workflow syntax/checkout-location review plus existing original harness/publish-tool tests; a narrow config regression may assert all7exact refs and that preflight binds actual gitHEAD. No new parser dependency/framework or formal profile/native test is needed. Only a later actual PR artifact can establish real GitHub head/API/pack identity; local expression simulation is not remote proof.

## Independent measured checkout bottleneck

Root's actual HEAD tree inventory:22,891tracked files/9,104,076,797bytes total; docs8,585,548,837bytes, assets≈484MB; local.git≈6.9GB. Current push prepare checkout began07:38:51UTC and was still checking out after07:41. This is actual CI preparation cost independent of duplicate events, artifact collection and the retired eight-room feature. Our earlier newly reachable pack estimate≈149MiB only describes incremental objects for push; it does not describe a clean CI checkout of the full committed tree. File-tree bytes also must not be called exact compressed network bytes.

This is a concrete optimization item, not yet a terminal failure. Do not delete old evidence or weaken portable/quality proof. A future finite evidence archive/index or audited sparse/on-demand checkout must preserve every file needed by real quality cards, archived-version tests and actual consumers. filter:blob:none alone still checks out all selected HEAD files and will not remove9GBtree cost. Any such change needs its own measured same-source coverage/evidence-closure validation; leave current c305 run untouched while collecting actual timings/failure evidence.
