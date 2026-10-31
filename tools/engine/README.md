# Fixed Godot 4.7.2 shutdown backport

This is a separately built **Standard custom distribution**, never an official Godot binary. Its source is the verified official 4.7.2 archive (`ed1daf0bf001b61586d9930840f2f1394092c079`) plus exactly upstream PR117991 and PR120976. The latter has two context-only adaptations for the 4.7.2 function-state destructor/header; all four final source hashes are locked. No game code or official check is relaxed.

`config/godot_build.json` owns the source-build recipe. `config/toolchain.json` remains the installation authority: update its artifact/member hashes only after the build outputs have been reviewed and published at permanent versioned URLs. The first recipe commit intentionally does not install placeholders or select the earlier diagnostic O0 binary.

The narrow five-line fix alone failed the actual game. The combined fix passed the original 191-assertion formal runner with clean teardown in an isolated diagnostic build, with byte-identical game source across A/B/C. These results justify constructing release candidates, not claiming all-suite or platform acceptance. The patch also affects ordinary script/function-state/instance destruction and cancelling suspended functions during hot reload; it is not merely a quit hook.

## Required outputs

| Lane family | Existing consumers and retained capabilities |
|---|---|
| Linux x86_64 | Editor for all native checks; debug/release templates retained by environment contract; X11, Wayland, AccessKit, OpenGL/Vulkan. Compiler is the fixed Godot Linux SDK using glibc 2.34, independent of the CI host's compiler. |
| Windows x86_64 | Required automatic workflow debug export, plus release and console templates. Includes ANGLE, D3D12, WinRT and AccessKit. No Windows execution or signing claim follows from cross-compilation. |
| Web wasm32 | Threaded debug/release for the public preset; non-threaded debug/release for existing mobile A/B tools. GDExtension stays disabled, matching current consumers. Emscripten 4.0.20 image is pinned by digest. |
| Android arm64 | Existing optional manual debug export and the current preset's sole enabled ABI; release APK and Gradle source template retained. Swappy enabled. Engine construction uses its own fixed NDK29/API36/build-tools36.1/JDK17, without rewriting the application's existing NDK28/API35 installer contract or preset. |

Unused official-template architectures/platforms are not silently copied into this distribution and labelled patched. macOS/iOS, additional Android ABIs, Windows ARM/x86, Linux ARM/x86 and Web dlink have no current enabled preset and are not claimed. Adding a consumer requires a matching build lane first.

## Build and promotion

The dedicated workflow only auto-runs on `fix/godot-shutdown-toolchain-01`; manual runs are explicit. It does not publish a release or modify the main workflow. Each lane uses a content-addressed Linux container, SHA256-verified compiler/SDK/auxiliary archives, SCons 4.8.1, the exact two patches and production optimization. It keeps logs and per-file hashes. Actual Godot runtime payloads must contain the precise custom build/source identity; a different official template cannot be substituted.

Run inside the lane's specified container:

```
GUNMAN_BUILD_IMAGE=<exact recipe image digest> GUNMAN_TOOLCHAIN_ROOT=/tmp/engine-downloads \
  python3 tools/engine/build.py --lane linux-editor --work /tmp/gunman-engine --jobs 2
```

A fresh work directory is required; a failed attempt's logs are not overwritten. Source-only checking needs no engine lease:

```
python3 tools/engine/build.py --work /tmp/source-check --verify-source-only
python3 tools/engine/test_build_contract.py
```

`package.py` requires all ten lane manifests and every expected file. It rejects mixed recipe/image/source/patch/build identities, missing lanes and modified outputs, then emits two deterministic zip containers, complete provenance, package/member hashes and an **inactive lock candidate**. Per-run logs/provenance contain timing and runner metadata, so the source recipe is reproducible and each result is content-locked; byte-identical compiler output across machines is not asserted without a second build comparison. Android Maven dependencies are the exact versions in the verified source and require their normal upstream resolution; full transitive cache reproducibility is not claimed here.

Root reviews the artifacts, publishes an immutable versioned release (never overwriting existing differing bytes), verifies downloads, then integrates the resulting exact lock plus strict installer/runtime checks. Existing installation budgets stay unchanged because normal CI downloads those fixed prebuilt packages. A temporary Actions artifact is evidence and a handoff, not the permanent installation source. No official template package is combined with patched runtimes.

The normal project core/entry/entity/reward/level/formal suites, focused reload/await cancellation checks, actual Windows/Android export, Web/PCK validation and public preview are subsequent acceptance work. A compiler success or the diagnostic formal result cannot sign those on its own.

## Installation identity

`tools/godot_identity.py` is the shared runtime path and identity authority for the wrapper, installer, environment check, Harness and capture producers. It requires the reviewed active lock, checks executable bytes before running even `--version`, and verifies the pinned source provenance. An explicit `GODOT_BIN` must match those same bytes. Export flags additionally verify the complete template member set and every SHA; native runs do not repeatedly hash the templates. The custom distribution uses its own data directory, leaving the official control installation and explicitly frozen historical diagnostics available.

`python3 tools/test_toolchain_download.py` retains the original downloader tests and also runs the source/package and installer identity rejection tests. Its synthetic shell/package fixtures are not native-engine evidence. Before promotion, the installer candidate intentionally rejects the still-official `config/toolchain.json`: root must integrate the reviewed actual artifact lock atomically with these consumers, without placeholder hashes or a fallback to arbitrary custom builds.
