# Five style experiment delivery

Task: WINDCHIME-FIVE-STYLE-01. The isolated experiment is deployed at [the public preview](https://zhipijun1996.github.io/gunman-rush/?styles=1&v=d2d469f81582).

- Build: `d2d469f81582`; exact runtime source: `32200d04fe233bda16cf50f678aabee51a9715e5`.
- Deployment [39229024220, attempt 1](https://github.com/zhipijun1996/gunman-rush/actions/runs/39229024220) succeeded without merging main.
- [Final delivery identity](final_delivery.json), [actual public full-PCK and license verification](public_verification.json). The full 119,400,768-byte PCK was downloaded and its complete SHA256 matched the local export.
- [Actual style PCK closure](final_pack_closure.json): 26 JSON files, 49 textures/imports, 23 runtime resources and 12 original license/notice files. Existing `check_web_bundle.py` also passed; see [log](final_existing_bundle_check.log).
- [Fresh browser input/OCR report](browser_final/browser_report.json): 23 checks covering the title pointer entry, five styles, four seeds, both shortlisted styles in three regions, Tile catalog, Home and direct URL entry. Screenshots include the rendered accepted style/region/seed.
- [Public HTTPS browser report](browser_public/browser_report.json): actual hosted loader, direct entry, and pointer switches through Cavern plains/forest/gear all passed; screenshots and HUD OCR are retained.
- [Toolchain verification](environment.json): exact Godot 4.7.2 Standard and matching templates. Native entry: `bash tools/godot.sh --path . -- --style-lab`.

The prepared branch transports existing verified gzip chunks because the full PCK exceeds GitHub’s single-file Git transport limit. CI restored the original byte-identical PCK before uploading Pages; the public site retains the full PCK URL. [Reconstruction tests](chunk_reassembly_tests.json) include standalone sparse-helper execution and six rejecting counterexamples. Licenses are also publicly downloadable at [style-licenses/index.json](https://zhipijun1996.github.io/gunman-rush/style-licenses/index.json).

The first browser pass completed the actions but failed an overly broad assertion on the browser’s default `/favicon.ico` 404. Its [original report](browser_initial_favicon_failure/browser_report.json), [classification](favicon_failure_classification.json) and validator are retained. The exact same runtime package then passed a fresh run that separates this default browser request from runtime errors and asset requests; no runtime bytes changed. The first native audio attempt also retained its ALSA failure; subsequent image/input checks explicitly used Dummy audio.

This is a scoped experimental playtest. Full project profiles remain blocked by inherited historical evidence closure; complete release, subjective aesthetics, listening and physical-device acceptance are not asserted.

The first public browser validator separately failed when Playwright’s APIRequestContext selected an unreachable IPv6 address for metadata. The Godot browser loader had already started. Its [original report](browser_public_api_ipv6_failure/browser_report.json) and [classification](public_api_ipv6_failure_classification.json) remain. The fresh pass reads metadata inside the loaded same-origin browser page; the runtime package is unchanged.

Independent review found a non-blocking helper boundary: deployed source B checked a safe pack filename and the content hash/build ID but did not equate the embedded filename ID to `build_id`. The helper now enforces that equality. A [real wrong-filename fixture](helper_filename_hardening.json) is accepted by the preserved B helper and rejected by the repaired helper, while the actual correctly named final package still passes. This is a post-deployment tool hardening change; the existing public PCK and its exact B source label were not rebuilt or relabeled.
