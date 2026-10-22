# Independent review of the first formal-route AV adapter

Verdict: **REWORK the adapter acceptance checks.** Reviewed SHA256 `c1d9d6599d1050b05f15f83d3038b02be1cbfb686433fa564dfad76d8a8c78ed`; the exact source is preserved in `adapter-reviewed.py.source.txt`. No engine ran and no production/test/tool source was modified during this review. This finding does not invalidate prior native route passes, and does not establish that an honest fresh native invocation can fabricate a movie.

The adapter correctly invokes the existing full-formal F05/F08 runners, keeps the original 90-second import and 240-second native limits, uses actual MovieWriter rendering and actual draw counters, prohibits LOCAL fixture/injection scopes, checks engine/GL/PASS/errors/leaks, binds full source inventories before and after native execution, and preserves equal decoded video frame counts across AVI and MP4. The launch and provenance design can be retained.

## Proven acceptance gaps

`probe.py` executes the reviewed functions themselves, with prior real native reports as the baseline and explicitly synthetic mutations as negative controls. `probe-report.json` preserves all results. Nine invalid variants were accepted:

- A frame with health zero; a committed player-damage event; changed actor epoch; changed stage epoch.
- Only one physical frame retained despite the original complete itinerary header.
- Final player far from camp, with claim and gate state removed.
- Every draw counter replaced by zero, including a version with every accepted event removed. Only one exported image remained, with no exception.
- F08's actual item evidence replaced with unrelated nonempty data.

`verify_trace` at reviewed lines 110–133 reports several safety facts without enforcing them. Enforce health 5 for all physical samples and initial/final snapshots, no committed player damage, exactly one unchanged actor/stage epoch, one ordinary Motor step per actual physical sample, continuous ordered ticks, actual itinerary identity/order/leg boundaries and frame coverage, return-to-manifest-camp, and the route's actual claim/gate/receipt effects. Required-event deletion must fail. A count of completed legs alone is insufficient.

`keyframes` at reviewed lines 136–159 silently skips missing required events and validates only selected counters. Validate the whole timeline, require the exact route-specific wanted events and contextual predicates, and retain all event labels when multiple facts share one real image. Do not approximate movie indices from ticks or accept constant draw counters.

`media_probe` at reviewed lines 88–107 accepts the explicitly named synthetic fixture `SYNTHETIC-NOT-GAME-static-short-silent-audio.avi`: 12 identical black frames at 1280×720/60fps with only **48 stereo PCM sample frames (1ms), all bytes zero**, instead of the 9600 sample frames corresponding to its video. `timeline-review.json` records the actual PCM extraction. Check actual PCM format, preserve a WAV by lossless audio copy, compare decoded raw PCM sample duration with decoded video duration, require actual nonzero audio for this sound-producing route, and measure decoded frame variation. Compare MP4's video count exactly and audio duration/sample evidence with explicit AAC priming/padding handling; do not manufacture, loop, pad or resample audio. Frame variation is a guard against a constant image, not proof of aesthetically successful animation or a substitute for continuous human viewing.

## Reusing the existing timeline validator without rejecting real process events

The existing `run_forest_depth_region.validate_movie_timeline` checks every actual counter's bounds/order, unique physics draws, and exact `events`/`requests` alignment to the physical tick's draw. Preserve these checks for all physics observations. Its all-event exact-equality rule cannot be applied unchanged to these new drivers:

- `forest_bible_world_trace.gd:154–158` emits `bible_actual_aim_release` in `_process`; its parent releases the actual mouse and records the actual aim sample there. Focus changes time scale, so multiple real process/draw frames can share a physics tick.
- `forest_bible_spiral_trace.gd:110` observes the actual queued item effect in `_process`.
- The Reader confirm release invokes App's synchronous `router.clear("forest_reader_confirm")` while paused, before the App queues the actual claim for later physics. Its cancellation signal has the old physics tick and a later actual draw.
- Both runners seal inputs after their awaited process frame resumes. Their exact terminal cancellation event can therefore occur after the final physical observation.

Observe the real invocation phase with `Engine.is_in_physics_frame()` at stamping time. All events still require valid, ordered, bounded actual draw/process counters. Run the unchanged exact physical-alignment guard on a validated physics-only view; independently validate every explicitly permitted process row rather than discarding mismatches. For an ordinary process event on tick t, require its actual draw in `[physical_draw[t], physical_draw[t+1])`, its process counter bounded by those physical observations, and its specific evidence. The last-tick terminal seal is a separate exact-reason exception bounded by final physical observation and actual film length, contingent on complete success. This half-open interval follows the engine's physics→process→draw order; the old non-movie traces do not prove new actual movie boundaries. Any failure in the first new movie sample requires preserving and diagnosing its raw counters, not loosening equality speculatively.

Permit only `bible_actual_aim_release` (matching its actual `aim_samples` row), F08's `spiral_actual_queued_item_accepted` (matching actual receipt/effect evidence after real Reader interaction), and exact modal/terminal cancellation reasons with scope-specific corroboration. A process cancellation must fall in its corresponding real modal/pointer window and preserve paused physics/Motor state. An unfamiliar reason or event must fail. Existing cancellation reasons observed in the prior real native reports are:

- F05: `region_cache`, `pause`, `region_cache_complete`, `Bible_world_trace_sealed`.
- F08: `menu`, `pause`, `forest_reader_confirm`, `forest_reader_close`, `Bible_spiral_trace_sealed`.

These are a list of observed reasons, **not blanket process exemptions**. Physics-phase occurrences remain exact by tick. Reader opening/confirmation must be tied to the four actual ordered press/release pointer rows and visible rectangle hits, Reader modal rows, then real post-physics acceptance. F05 cache modal acceptance requires its own actual modal/pointer rows.

The current F05 raw report exports neither requests nor modal/pointer arrays, even though its actual observer already stamps those arrays. The current F08 raw report exports pointer and reader-modal arrays but not requests. Its reader-modal append currently has only `process_frame`; it does **not** call `movie_stamp`, so actual presentation counters must be added at the real observation. Exporting original observed arrays and adding actual observation stamps is valid; deriving or synthesizing missing historical timestamps is not. An empty absent group should never be mistaken for proof that all requested observations were verified.

## Actual required events exist

Prior real native F05 `grounded-v3-map1-backbranch-first/trace.json` has 3129 physical frames and 32 completed legs. Its F05 departure is tick 2354, descending side cast 2383, subsequent actual H contact 2428 and subsequent actual shot 2463, all on leg 25. Thus requiring the adapter's wanted events is supported by actual data. The descent predicate must additionally remain airborne/outside-body and refer to its actual target.

Prior real native F08 `f08-full-01/trace.json` has 3551 frames and 31 completed legs. A true deep-ascent H contact is tick 2317 on leg 17; Reader bank is tick 2531 and actual queued item acceptance 2535 on leg 18. The actual report has four real pointer press/release rows and six paused modal process rows on tick 2534, fixed motion_steps 2541. Required events and exact receipt effects can therefore be checked rather than accepted as nonempty dictionaries. No actual movie counters are present in these historical reports: they are positive gameplay-schema fixtures, not positive AV-timeline fixtures.

The scoped repair should retain original routes, pilot inputs, game mechanics, source freeze, error handling and native budgets. Re-run these no-engine negatives against the fixed functions, include positive and bounded-process negative timeline controls, then run one fresh source-bound real sample only after the parent grants the exclusive engine lease. Native AV, motion quality, audio quality and pixel-style consistency remain unverified by this static review.
