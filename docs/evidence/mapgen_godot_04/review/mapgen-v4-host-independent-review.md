# 0.4 host envelope and slice — independent static review

**Accept the limited frozen control-flow scope and the reviewed dev03 job/default-slice execution evidence. The original dev02 failure is preserved; its narrow async test-lifetime followup now has a clean actual run. Final12/Web and gears acceptance remain separate.** I did not author the reviewed host code and did not run Godot,browser,pure tests,wrappers or generation. I read source/control-flow and existing shared owners only; no reviewed code was edited. Three B runners were still changing and are not signed. Parent's ongoing native results are not borrowed.

| Reviewed leaf | SHA256 |
|---|---|
| experiments/generation/runtime_map_slice.gd | `5b7d6157c1c1979717aa99adf0be6e637075d396126a2efdf9c01da08aaf53ec` |
| experiments/generation/runtime_map_generation_job.gd | `e7127ec6b9e87d2a49d5c2b09a8a7acdffb74ae90bbf9d5296d85a362fabc454` |
| experiments/generation/runtime_map_generation_profile.gd | `65040947b8d9467c36ca1052491d8e4abec785026a84f08eca765e7074037127` |
| experiments/generation/runtime_map_generated_selection.gd | `6515df69e0665b509c55ada2828fab5fb1fa7e5c9879910e8cd2c23f2820d7a8` |
| experiments/generation/runtime_map_generated_slice.gd | `2005cf5fdd5f3ae07007a79334e598f493590c2829e178690411ed4d51520130` |
| experiments/generation/runtime_map_m35_slice.gd | `0bab010547cd951caa7d78b9cfca8aa49f49743636825099dc71d61876a14315` |
| resources/levels/mapgen_host_v4/bindings.json | `182b4b50da807ace3b38b327645d156f02f73286d976b4de6dbace4590bc2809` |
| resources/levels/mapgen_host_v4_gears/bindings.json | `ef7fab5184d503c11d3ce0990f802acc620ec68ff070dacdbc242adec474ca4c` |

## Findings resolved during review

Initial jobfa50 allowed1..4096 requested units, so128 was only default, not a hard cap. I reported this discrepancy. Parent explicitly chose to preserve the compatible API rather than clamp it. Final metrics configured_work_unit_cap makes the requested limit explicit; **this review accepts default128 and never claims an unconditional hard128 ceiling**.

Initialfa50 cancel/fail preserved counts/overruns/progress but cleared SDK objects without their missing phase profiles. I reported that diagnostic gap. Finale7127 adds _capture_missing_profiles: after original cancel, before clearing objects, capture only profiles not already saved and actual terminal status; measure cancel_profile_ms/cancel_ms. Normal completed close does not repeat sorting. This is statically sound; runtime/syntax success remains for the parent's actual process. The report retains both initial findings and exact superseded hash.

## One player, seed and capability authority

Base RuntimeMapSlice differs from7f65 only by a source-seed hook and using its one value for existing flow.start and LevelRequest.root_seed; frozen default hook remains930001. Existing RunComposition creates one actual player, RunSession creates one shared BuildState/wallet/reward/shop set, and one lifetime remains owned by the original flow. configure_capabilities(true,false) enables existing energy and does not grant grapple. No second service,session,physics owner or App wrapper is introduced.

GeneratedSlice obtains one typed locked Profile snapshot before flow.start. read_profile checks request/config file hashes and uses original DATA.parse to retain integer seed; conformance uses930001 and gears its own930007. The same captured seed feeds flow/manifest,LevelRequest and from_controller algorithm request. Job takes deep copies of request/config/bindings/capabilities and actual PlayerTuning SCRIPT_VARIABLE values; the prior Resource.duplicate nonexport-variable loss is not reintroduced.

The conformance request remains distinct from actual controller authority. from_controller reads the real motor/abilities/weapon/energy/collider bindings, and GeneratedSlice stores its actual collision_half_extents and nominal actual ability tags in request.capabilities. Conformance may retain upstream double_jump/grapple generation tags, but no grant call applies them. Controller profile uses the actual builder request instead. Static review proves this separation, not physical reachability of all generated routes.

## Cooperative scheduling and observability

Both preload and solve loop over original advance(1), one SDK unit=16 checkpoints. They stop when the requested unit cap is reached or elapsed host work reaches the4ms soft target after a full call. Default request cap128 means up to2048 checkpoints if time permits; API permits1..4096 units. No elapsed-time check interrupts an atomic upstream call, synchronous validation/Provider conversion or profile sort. There is no hard4ms/FPS promise.

Host tick durations/phases/maxima are separate from original unit count/total/max, and every over4ms unit is retained. Solver operations/microsteps are retained independently. Progress dictionaries are sampled initially/per host tick/terminal, not appended for every one of tens of thousands of advance units. Original SDK phase profiles remain original gate profiles, not a rewritten solver instrumentation scheme. Final cancel/fail captures missing profiles before clearing and records cancellation cost. Inline PREDELETE still avoids self method dispatch; normal explicit close owns cleanup.

## Actual result and current ticket only

Caller receives an opaque RefCounted handle; Ticket state is private to the envelope. Serial/current handle, weak valid owner, exact current lifetime and accepted epoch token gate advance,take,result,provenance and commit. Old/replaced handles cannot refer to replacement state; take is once, commit requires assemble/taken/uncommitted. Close marks the source closed before cancellation; afterexit and duplicates cannot commit. Source work remains synchronous main-thread data code with no SceneTree awaits or callback/service bag.

04 begin refuses nonempty pinned instance-ID input and requires selection_recipe. The checked-in recipes contain empty selection/spawn placeholders. Selection uniquely resolves current module template/content_version/role and exact original port topology; gears additionally requires actual unmirrored/no-seal source. It computes platform0 top-center from current materialized content, actual origin×128 and actual body height, then overwrites placeholder IDs/spawn and records current result fingerprint/geometry identity. No old M IDs,old spawn,restore identity,second mirror or source_affine application is reused.

_validate checks completed result/schema and original Protocol fingerprint against captured provenance/result/map, invokes the same selection and shared Provider, and retains the full actual map/store. There is no frozen map/content fallback,hidden unsafe Plan or second converter. Generated reload explicitly refuses and leaves the current world intact; returning to a fresh job requires exit.

## Physics barrier before activation and commit

GeneratedSlice process takes the current ready plan once and uses the existing base assembler. The actual controller remains inactive throughout asynchronous frame waiting. Initial return_to_segment uses the prior synchronous temporary-active fix, checks its boolean and restores the original inactive value; no Motor tick runs within that call. There is still only the original LevelRuntime/PlainsRegionAssembler collision set.

At the next physics callback the pending build must still have a current token. SegmentRespawn is configured with the actual controller/lifetime and original world dangers; activate_anchor uses existing full rectangle overlap and three support rays. A rejected anchor clears/detaches Stage and policy, keeps the controller inactive and never reaches manifest commit. After admission, a later process checks current token again before base _commit_plan and source commit; actor invalidation in between therefore refuses. Actual loaded observation is emitted only after this barrier; player activation follows successful commit. Existing static emitters and saws check controller.active, so pending inactive assembly does not deal contact damage.

Static ordering is coherent; only actual native cases can establish collision registration timing,body/foot results,unsafe rejection and after-admission invalidation. The still-changing tests and ongoing wrappers are excluded from this signature.

## Complete gears lifecycle on original owners

Gears subclass checks actual resolved instance/template/version/role before admission. Provider's existing definitions retain every authored hazard,saw and both linear ferries; Stage binds their original shared module clock and one FrameDamagePolicy. Original platform/saw/linear motion code and shared player/combat services remain unchanged. No alternate trajectory or replacement HP store is introduced.

Environment return uses existing SegmentRespawn safe anchor, preserving actual HP,world clock and run services while invalidating actor epoch and clearing transients through the original return function. An unsafe anchor stops safely with no blind fallback. Void uses the original DamageBoundary and ENVIRONMENT1HP requests with token/health/actor epochs and unique event IDs. The original policy resolves fatal priority, then die plus flow.end_failure ends the run without automatic restart; ESC remains available for cleanup. These are source/lifecycle findings, not newly tested damage spacing,physical ferry rides or route completion.

Acceptance is restricted to this exact source vector and static control-flow. Root must separately bind final actual native logs and frozen runners, then actual export/PCK/browser if claimed. Whole-map,uncovered mechanics,phone,performance,hard frame budgets,user acceptance and zero resource leaks remain outside scope.

## Actual dev02 disposal failure — initial analysis before dev03, preserved

After the static review, I read `/tmp/mapgen-v4-audit/native-dev-02/generation_job.log` (SHA `dda140deb48fd794ba7e81548c8385cb968cf69b643c1f9cdf4e6ab36fc71973`) and its receipt. The real job wrapper exited1 after39.939s, marker2514checks/1failure. Its only observed native ERROR is the PREDELETE fallback immediate weak-release assertion; backtrace still includes disposal_contract260 ← suspended73 ← preload_source66. The failing runner observed at review had SHA `bb4d5b917de77de471f14c6b5b5ca609b707cf1ea7144a3b5a6672805839e193`. Other typed/source or partial results cannot convert this job run to PASS.

03 preload_source/suspended were synchronous.04 preload_source(source:SOURCE) awaits process_frame and suspended awaits it; both callee frames retain strong SOURCE parameters. A caller resumed inline by their completion can clear its local source and immediately check WeakRef while those completed callee stacks are still unwinding. The shown backtrace supports this timing explanation. The object graph has no identified SDK→host strong backreference: Ticket.owner is weak, the opaque handle has no Ticket/source state, and SOURCE only owns its pure SDK jobs. Thus the evidence more strongly suggests an async test lifetime assumption than a demonstrated permanent production leak. This is a hypothesis requiring an actual bounded-frame disposal run, not a static proof of teardown.

This raw log contains no ObjectDB-leaked/resources-still-in-use diagnostic. That absence does not mean the strict wrapper passed: run_engine raises on returncode1 before its subsequent teardown/marker checks. Appropriate narrow followup is test-only: drop the local reference, allow exactly one process_frame for the completed helper chain to unwind, retain the original WeakRef-null plus opaque-handle-script-null assertion, record references/before/after, and demand a fresh clean engine exit. Calling close would mask the intended unclosed PREDELETE test and is unsuitable. B reports this one-frame diagnostic runner change184215c8 with productione712 unchanged; at that earlier review point no new PASS had been read. Parent owns the sole engine run. Original2514/1 remains failure evidence.

## Dev03 followup: minimal test change and actual clean exit

I subsequently read actual dev03 generation_job.log, SHA `71784433ba494a09620ce98abe66b703c2a54649e8d5e1bde9b70311b8b26615`, and its successful receipt: **2401checks/0failures,strict wrapper exit0,41.792s**. The production source remains exacte7127; no destructor or ownership workaround changed it. Test runner is `184215c830f3fd350152375357d2a8f7b14b5115f4a33600e08d9fd1ec3b2b26`. I independently reversed only the added diagnostics/one-frame block and recovered the entire failed runner SHA bb4d5b…exactly. Thus no other test/guard/assertion was deleted. The2401 versus2514 count comes from the check inside each real host generate tick; soft elapsed-budget timing changes tick count, not the fixed assertion set.

The raw new diagnostic is references_before_release=3,released_before_frame=false,released_after_frame=true. Exactly one process_frame allows the completed async preload/suspended parameter stacks to unwind; the original WeakRef-null AND opaque-handle-script-null condition remains. No close call masks the unclosed fallback branch. I scanned the complete new log: no ERROR,SCRIPT/PARSE/SHADER error,ObjectDB-leaked or resources-still-in-use diagnostic. The original shared wrapper returns0, so its nonzero-exit and strict teardown/summary gates actually ran. Together this supports the async test temporary-reference explanation in the exercised scenario, rather than a permanent SOURCE leak. Original dev02 2514/1 is still failed and retained. This is review of the parent's actual engine run, not my independent execution or universal no-leak proof.

Default generated_slice.log SHA `31026b7618a72b199862146773e51dba9904024457240eccd45ea29e87b18d84` separately reports58/0,wrapper exit0,31.370s,with no strict diagnostic. Its current runner SHA is32faf6671e9147a08f086369ba08e86400f483c3afc153c8d98fc9792be66e74. I read the exercised checks for actual Stage/body-foot admission and the same captured profile seed in flow/LevelRequest. Four actual files exist under build/mapgen_godot_04/default: result,provenance,host_bindings,protocol_payload; individual current bytes/SHA are in this JSON. This does not pre-sign the still-running gears wrapper,final12,Harness archive contents or Web outcome.

## CI artifact-directory append

I compared tools/harness/profiles.json (current SHA76a576bf3f501e345e5a3284e1e0ebe56e8efc130cf15d179ea08de1b47a963b) with7f65. All226 definition keys and every profile list,including full178,are retained. Exactly two existing definitions differ, solely by appending artifact_paths: runtime-map-generated-slice adds build/mapgen_godot_04/default; runtime-map-m35-runtime adds build/mapgen_godot_04/gears. Each keeps build/mapgen_godot_03 first. All commands,budgets,success markers,input declarations and other definitions remain exact. These are directories, suitable for the Harness recursive artifact scan,so the four actual files can be captured instead of relying on an individual JSON base path. Actual final Harness custody capture must still be verified when produced.
