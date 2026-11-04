# MAPGEN-HOST-V2-02 actual Web evidence review

**ACCEPT for the observed local Web loading, directional input, moving-platform observation and two preview exits, with the console messages below disclosed.** No blocking mismatch found within that scope. This is independent review of the producer's raw report and six actual screenshots, not a second browser execution. No production changes or engine/browser runs by this reviewer.

Reviewed source `67da2f3596880cbdad22496a649dd68f7af7d5a6`, Chromium154.0.8037.57, local127.0.0.1 preview, build `ca7b47b3f398`, actual PCK216993944B / SHA256 `ca7b47b3f3980630f46eb4c318319f93f628ce5918acf54a8ef775fa35efafa1`. Raw report is `web-browser/actual01/report.json`, SHA256 `44514ff2fc120e81c65d77e79d20c79a037a5c941f6edb7eca662af1084ecb05`. Reported total249.218235s is within the unchanged300s two-context budget.

## Actual pixels viewed

Opened all six original1280×720 PNGs with view_image and independently checked their recorded SHA. Both `menu-click-01-loaded.png` and `escape-01-loaded.png` show the actual MAPGEN loading-slice label, M16/M18/M21 source terrain, courier and separate moving carrier, plus the current development banner/build badge. Both corresponding `02-after-input` frames show camera-relative terrain and carrier changes; player facing changes appropriately. Both `03-returned-title` frames visibly show the real Chinese title with Start, Continue, Settings, Tutorial and Development controls, clock artwork and matching build badge. These are game pixels, with no blank/error screen. They do not establish animation or sound quality.

## Input, identity and exit chain

The producer uses two fresh browser contexts. The menu-click case sends real D down/180ms wait/up; passive source observations show player x moving from−448 to−391.666565, delta+56.333435. The escape case sends real A with the same planned180ms hold; x moves from−448 to−504.333435, delta−56.333435. These are short real input responses, not180 rendered frames. Source observations report carrier displacement315.798094 and grounded samples. The screenshots corroborate changed camera/terrain/carrier positions, but do not prove the player rides the carrier or crosses a seam.

Menu return is a real OCR-selected mouse click at497.5,238.5; the other context uses the actual Escape key. In each raw console, audio teardown reports released=true, followed by exactly one source closed observation with audio_released=true, lifetime_active=false and stage_detached=true. Both closed observations precede the real-menu persistence=false return log, and the returned-title pixels agree. This supports the intended cleanup ordering; it does not prove all queued nodes, GPU/audio objects or browser allocations have zero retained resources.

All loaded/physics observations in both contexts carry the same host-load identity `6b7a05c197663e1396e1177f2fe76a7b0dc5eeff1a898259ac5a3b8a13044b9c`. Served source/build/PCK identity and launch flags remain equal before/after. Seven raw JSON readbacks match this reviewer's independently read PCK members from `final-static.json`. Independently decompressed the full before/after source snapshots: raw bytes and recorded SHA are equal. Producer/helper/source/pack hashes are equal before/after and match their current files.

## Original console retained

Both contexts have empty page-error, request-failure, HTTP-response-error-event, parse-error and classified-script-error lists. **The raw console is not error-free.** The menu-click context contains an explicit `http://127.0.0.1:8815/favicon.ico`404 console error. Each context also contains the Emscripten engine message `Blocking on the main thread is very dangerous, see https://emscripten.org/docs/porting/pthreads.html#blocking-on-the-main-browser-thread`, recorded as type:error. These three original messages remain in the review receipt. Their effect on frame pacing was not measured; there is no FPS or all-errors-zero acceptance here.

This supplements the earlier static review's then-pending Web status only for the exact observations above. No Web cross-seam traversal, carrier riding, full map/enemy/reward/Boss playability, publication, phone/device behavior, FPS, complete resource leak freedom, continuous audiovisual quality or user acceptance is signed.
