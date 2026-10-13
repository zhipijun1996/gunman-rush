# Independent strict review: Foundry mobile selector

2026-10-13. Reviewer is a fresh agent, independent of implementation. Scope: GUI popup font, touchscreen selection and escape from modal state, attempt lifecycle and pause. Emulation is not Android device acceptance.

## Pre-fix failure preserved

Local Web build `3b3c659b0049`, Chromium SwiftShader, Playwright context `viewport=1280x720,is_mobile=True,has_touch=True,device_scale_factor=1`. Real browser `touchscreen.tap` events, no engine-state writes.

Steps: wait for PLAYTEST_LOADING_DONE; tap title DEVELOPMENT DEMOS (640,500), LEVEL FOUNDRY (345,615), ability selector (1100,207); tap first popup row (1100,245), second row (1100,273). All screenshots show the popup still open after subsequent taps, with base profile retained. Chinese popup text renders fallback glyph boxes, although the main button and ordinary labels render Chinese correctly. See `independent/pre_fix_popup.png` and `independent/pre_fix_second_row_tap.png`.

Gameplay elapsed counter advances from 3.1s to 7.7s during these inputs. Thus this reproduction establishes a trapped modal input state, not a physics-thread freeze. User's real-device freeze remains reported; do not claim identical device cause solely from browser emulation.

Code evidence: OptionButton and reference MenuButton override only their main Control font; their PopupMenu child lacks a font override. TouchOverlay uses `_unhandled_input`, so the general assertion that its `_input` intercepts all GUI touches is false.

## Post-fix review

First fix replaces modal controls with inline normal Buttons. FontTools CJK scan finds no missing glyphs in FoundryLab/capabilities/sources. Native actual ScreenTouch fixture passes 10 checks (profiles, disabled hook, paused profile switch, another visible level, width fit, cleanup), Godot exit 0. Exit still emits 14 ObjectDB leaks and 2 resources in use; preserved verbatim, not called a clean engine teardown. One earlier fixture run overlapped source/batch rebuilding and rejected stale evidence; preserved as overlapping_build_failure.log, rerun after rebuild passes.

Browser build 5389dc6563ed, 1280x600 mobile/touch context with correct internal letterbox scaling: actual taps select second-jump and four-shot profiles, pause, switch back to base while paused, choose another visible level, show and hide inline references, and choose another level afterwards. Chinese text readable; no modal windows. Browser console no script/page exceptions, one generic 404.

**First fix rejected as incomplete:** CDP touchStart/touchMove/touchEnd swipe at virtual (1120,405) to (1120,282), 9 motion steps 25ms apart, leaves the 24-row base list at the top. See independent/first_fix_touch_scroll_failed.png. Lower levels remain unreachable by normal swipe; current native runner only taps first visible rows. Requested explicit touch-friendly paging or verified touch scrolling before approval.


## Second fix

Explicit 3-level and 2-source page Buttons remove dependence on touch swiping. Independent native fixture now passes 17 checks including final 24th level, last source page, closing sources and choosing another level. Exit warnings persist (4 ObjectDB instances / 2 resources in this run).

Second-fix local Web build 408f82ab: actual touch seven Next presses reaches the final eighth base page; tapping last row loads `落点收束后换支撑 · V2 / P1`.

**Second fix layout rejected:** page Label inherits smart wrapping and receives almost zero width in the HBox. `8 / 8` becomes three vertical lines, raises page-row height to about 100px, and moves the action buttons over JUMP. Screenshot `independent/second_fix_page_label_wrap_failed.png`. Requested no-wrap page Label with a fixed readable minimum width. Do not claim source-toggle fixed coordinates until correcting this.


## Final functional browser review before hit-area spacing correction

Local Web build 603081d4e9d7, 1280x600 touch/mobile Chromium with correct internal canvas letterboxing. Actual touchscreen taps confirm profile selection, pause, selecting base while paused, seven Next presses to a readable single-line 8/8, loading the final24th base level, previous page, switching to inline reference list, three Next presses to 4/4 with the final2 sources, closing sources to restore1/8, and selecting the ferry phrase afterwards. No script/page exceptions; one generic404. Screenshots final_last_page, final_last_level, final_last_source_page and final_after_sources_other_level capture the results. JUMP remains visible below actions; parent subsequently measured a1px hit-area overlap and is correcting VBox spacing, so final geometric approval remains pending that correction.

Final frozen native fixture first run failed only combined paused-profile-switch readiness assertion after7physics ticks. Same fixture immediate recheck passes17/17, logging paused=false,jumps=1,ready=true. Both logs retained. _load explicitly awaits process_frame after physics_frame, so a7-physics-tick wait alone is not sufficient to prove process readiness during catch-up; no permanent freeze was observed. This does not justify changing trajectory or physics thresholds. Recheck retains6ObjectDB/2resources exit diagnostics.
