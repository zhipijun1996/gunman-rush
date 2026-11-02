# 最终优化引擎：35入口有限交互验收矩阵

读取主树 `05c3e3dba43f3fc9283aa74198a9bf0d04d99bfb`。优化引擎构建41180438395仍待最终产物/工具链身份验收；以下均未执行。原35入口矩阵复用并纠正，未新增扫描器/runner/生产注册表。

**先决条件：** root激活精确审核的优化editor+同源templates+lock，再使用原tools/godot.sh。当前主树仍有official前缀guard，不通过GODOT_BIN伪装/绕过。新的引擎身份使旧native通过不能直接继承。

没有一组现成runner能证明35入口所有用户交互。下面是现有覆盖的最小有界集合；不能把未覆盖入口或118动态加载概称PASS。完整full182是发布的另一原约束，不能由本targeted矩阵替代。

## 关键执行顺序

1. 先primary-harness，最先item-v5-formal原严格退出门；保留191/0但泄漏失败历史，不能仅看断言。core已包含ModuleLab/Random实际消费者，不额外重复polish_regression。
2. 最终引擎上原Foundry build36条→stamp；对tracked输出diff审查，冻结basis后才运行lab/touch/feedback与导出。不得手写SHA。
3. 跑原3个Director精确场景交互、Home/Ambience共享transport、4个motion/landing/weapon场景生命周期；它们补足owners仅启动/所属关系的边界。
4. 原Forest directional golden补实际Motor正反例；不代替正式Forest80路线。

### primary-harness

11 existing checks: strict formal exit gate first; core includes ModuleLab/Random consumer interaction so do not repeat polish_regression.

```bash
python3 tools/harness.py --jobs 1 --release --check item-v5-formal --check core --check player-default-integration --check studio-input --check blob47-foundation --check windchime-plains --check pixel-plains --check style-exploration --check cloud-preview-runtime --check entry-audio-lifecycle --check entry-audio-owners
```

### foundry-rebuild

After final source/engine activation: original real physics base24+double_jump6+air_chain6; tracked metadata/replays can change, review real diff; no fabricated SHA. Import120s + each original profile300s.

```bash
python3 tools/foundry.py build --count 24 --promote
```

### foundry-stamp

Only after successful rebuild; current-basis validation then writes existing export_basis.json. Must precede exportedpack acceptance.

```bash
bash tools/godot.sh --headless --path . --script tools/foundry_export_stamp.gd
```

### foundry-lab

Actual App→Foundry ready, six real recorded route playbacks, supported exit, pause/resume, profile abilities, return HP/stamina and normal feedback write.

```bash
python3 tools/run_audio_lifecycle_tests.py --script tests/foundry_lab_runner.gd --marker '^FOUNDRY LAB: [1-9][0-9]* assertions, 0 failures$' --timeout 180 --output build/entry-final-41180438395/foundry-lab
```

### foundry-touch

Actual Foundry scrolling/selection UI and touch input, pause/leave.

```bash
python3 tools/run_audio_lifecycle_tests.py --script tests/foundry_touch_runner.gd --marker '^FOUNDRY TOUCH: [1-9][0-9]* assertions, 0 failures$' --timeout 180 --output build/entry-final-41180438395/foundry-touch
```

### foundry-feedback

Actual feedback panel open/save/cancel, prior pause preservation, separate local feedback, enemy toggle and return lifetime. These3 are complementary, same root class is not3 entries.

```bash
python3 tools/run_audio_lifecycle_tests.py --script tests/foundry_feedback_runner.gd --marker '^LAB FEEDBACK: [1-9][0-9]* assertions, 0 failures$' --timeout 180 --output build/entry-final-41180438395/foundry-feedback
```

### audio-director-lab

Exact hosted Lab v1: actual Home current body, Router jump/shot, A/B/C selection, Home/Plains/Forest route switches, drain.

```bash
python3 tools/run_audio_lifecycle_tests.py --script tests/audio_director_lab.gd --marker '^AUDIO_DIRECTOR_LAB checks=[1-9][0-9]* failures=0$' --timeout 180 --output build/entry-final-41180438395/audio-director-lab
```

### audio-director-v2

Exact hosted v2: ready; original/A/B/C accepted shop/denied/button/projectile/hurt/coin/heal reward fixtures; combat context, pause and shutdown.

```bash
python3 tools/run_audio_lifecycle_tests.py --script tests/audio_director_v2_scene.gd --marker '^AUDIO_DIRECTOR_V2_SCENE checks=[1-9][0-9]* failures=0$' --timeout 180 --output build/entry-final-41180438395/audio-director-v2
```

### audio-director-reels

Exact reels PackedScene: all declared reels, selected profiles/accepted timelines and audio cleanup; scripted auditions, not human listening.

```bash
python3 tools/run_audio_lifecycle_tests.py --script tests/audio_director_reels.gd --marker '^AUDIO_DIRECTOR_REELS checks=[1-9][0-9]* failures=0$' --timeout 180 --output build/entry-final-41180438395/audio-director-reels
```

### home-audio-service

Actual Home audio adapter+GameAudio deterministic source scheduling/modes/pause/lifecycle; not audio_home_lab scene UI controls.

```bash
python3 tools/run_audio_lifecycle_tests.py --script tests/audio_home_runtime.gd --marker '^AUDIO_HOME_RUNTIME checks=[1-9][0-9]* failures=0$' --timeout 180 --output build/entry-final-41180438395/home-audio-service
```

### regional-ambience-service

Actual GameAmbience listener/origin/transport lifecycle fixtures; not audio_ambience_lab UI mode interaction.

```bash
python3 tools/run_audio_lifecycle_tests.py --script tests/audio_ambience_runtime.gd --marker '^AUDIO_AMBIENCE_RUNTIME checks=[1-9][0-9]* failures=0$' --timeout 180 --output build/entry-final-41180438395/regional-ambience-service
```

### motion-candidate

Exact MotionCandidate scene; real ready, enable/disable/reset and lifecycle adversarial checks.

```bash
python3 tools/run_audio_lifecycle_tests.py --script tests/player_presentation_01/motion_lifecycle.gd --marker '^MOTION LIFECYCLE: checks=[1-9][0-9]* errors=0$' --timeout 180 --output build/entry-final-41180438395/motion-candidate
```

### landing-feel

Exact LandingFeel scene: real Home terrace drop, heavy recovery/shake, toggles/pause/cleanup. Source uses real Router/Motor route. Existing runner requires a new --output file and refuses overwrite; command uses original run_engine, no new runner.

```bash
python3 -c 'import json,re,sys; sys.path.insert(0,"tools"); from run_tests import run_engine; out=run_engine(json.loads(sys.argv[1]),180); assert re.search(sys.argv[2],out,re.M), "missing original complete lifecycle marker"' '["--headless", "--fixed-fps", "60", "--path", ".", "--script", "tests/player_presentation_01/feel_lifecycle.gd", "--", "--output=res://build/entry-final-41180438395/landing-feel.json"]' '^FEEL TRACE: samples=[0-9]+ checks=[1-9][0-9]* errors=0$'
```

### weapon-feel-entry

Exact WeaponFeel scene: real controller/projectile/target feedback and enable/disable/change/reentry lifecycle. Existing runner requires a new --output file and refuses overwrite; command uses original run_engine, no new runner.

```bash
python3 -c 'import json,re,sys; sys.path.insert(0,"tools"); from run_tests import run_engine; out=run_engine(json.loads(sys.argv[1]),180); assert re.search(sys.argv[2],out,re.M), "missing original complete lifecycle marker"' '["--headless", "--fixed-fps", "60", "--path", ".", "--script", "tests/player_presentation_01/weapon_lifecycle.gd", "--", "--output=res://build/entry-final-41180438395/weapon-feel-entry.json"]' '^WEAPON TRACE: samples=[0-9]+ checks=[1-9][0-9]* errors=0$'
```

### weapon-feel-v2-entry

Exact V2 scene and real formal scene: six weapons feedback observers, accepted audio, leaf restoration, formal projectile binding/reentry. Existing runner requires a new --output file and refuses overwrite; command uses original run_engine, no new runner.

```bash
python3 -c 'import json,re,sys; sys.path.insert(0,"tools"); from run_tests import run_engine; out=run_engine(json.loads(sys.argv[1]),180); assert re.search(sys.argv[2],out,re.M), "missing original complete lifecycle marker"' '["--headless", "--fixed-fps", "60", "--path", ".", "--script", "tests/player_presentation_01/weapon_feedback_v2.gd", "--", "--output=res://build/entry-final-41180438395/weapon-feel-v2-entry.json"]' '^WEAPON V2 TRACE: samples=[0-9]+ checks=[1-9][0-9]* errors=0$'
```

### forest-golden

Existing fixed golden source.new real Motor four positive/negative arch cases. Separate exact PackedScene startup remains root probe; not formal Forest80 route suite.

```bash
python3 tools/run_forest_directional_golden.py --output-dir build/entry-final-41180438395/forest-directional-arch --layout arch --variant all
```

## 每入口覆盖

| # | 入口 | 原交互runner组 | 未证明边界 |
|---|---|---|---|
| 1 | `experiments/motion/entries/action_studio.tscn` | primary-harness | Full human keyboard/touch weapons/navigation needs existing Web GUI trio. |
| 2 | `experiments/terrain/entries/blob47_lab.tscn` | primary-harness | Device/GPU appearance not headless acceptance. |
| 3 | `game/application/demo.tscn` | primary-harness | Finite scripted routes do not prove every seed/full formal loop, browser GUI, persistence across installed builds or physical device. |
| 4 | `experiments/generation/entries/forest_directional_golden.tscn` | forest-golden | Exact PackedScene startup separate; full formal Forest acceptance not this golden. |
| 5 | `experiments/generation/entries/foundry_lab.tscn` | foundry-rebuild, foundry-stamp, foundry-lab, foundry-touch, foundry-feedback | Direct packed root startup separate; current basis must be regenerated by actual engine, cannot inherit old replay PASS. |
| 6 | `experiments/generation/entries/module_lab.tscn` | primary-harness | Direct standalone PackedScene startup recorded separately; no claim all module geometry crossed. |
| 7 | `experiments/terrain/entries/pixel_plains_preview.tscn` | primary-harness | Device/GPU appearance not headless acceptance. |
| 8 | `experiments/terrain/entries/plains_polish_review.tscn` | 没有现成精确交互runner | Original explicit Boss8 stage-index fixture assumes retired room flow; formal Boss tests do not certify this exact preview. Record actual startup result separately and isolate any legacy defect; no supplied original interactive runner proves it. |
| 9 | `experiments/generation/entries/random_stage_preview.tscn` | primary-harness | Not exhaustive generator seeds. |
| 10 | `experiments/terrain/entries/windchime_lab.tscn` | primary-harness | Device/GPU appearance not headless acceptance. |
| 11 | `experiments/audio/entries/audio_ambience_lab.tscn` | regional-ambience-service, primary-harness | Exact Lab UI three-mode/context/preset complete interaction not proven. Capture scripts are media workflows, not interchangeable with this finite native gate. |
| 12 | `experiments/audio/entries/audio_director_lab.tscn` | audio-director-lab, primary-harness | Actual audible mix/listening/device not signed by event counters. |
| 13 | `experiments/audio/entries/audio_director_lab_v2.tscn` | audio-director-v2, primary-harness | Actual audible mix/listening/device not signed by event counters. |
| 14 | `experiments/audio/entries/audio_director_reels.tscn` | audio-director-reels, primary-harness | Actual audible mix/listening/device not signed by event counters. |
| 15 | `experiments/audio/entries/audio_home_lab.tscn` | home-audio-service, primary-harness | Exact Lab UI three-mode/context/preset complete interaction not proven. Capture scripts are media workflows, not interchangeable with this finite native gate. |
| 16 | `experiments/terrain/entries/authored_terrain_study.tscn` | primary-harness | Preset switches/actual visual outputs/device controls not exhausted. |
| 17 | `experiments/platform/entries/cloud_preview.tscn` | primary-harness | Web URL/embedded canvas/history/cache/deep links require real exported browser checks. |
| 18 | `experiments/terrain/entries/high_density_terrain_study.tscn` | primary-harness | Preset switches/actual visual outputs/device controls not exhausted. |
| 19 | `experiments/terrain/entries/light_study.tscn` | primary-harness | Preset switches/actual visual outputs/device controls not exhausted. |
| 20 | `experiments/terrain/entries/pixel_light_study.tscn` | primary-harness | Preset switches/actual visual outputs/device controls not exhausted. |
| 21 | `experiments/motion/entries/landing_feel.tscn` | landing-feel, primary-harness | No proof full visual animation quality or physical-device input. |
| 22 | `experiments/motion/entries/motion_candidate.tscn` | motion-candidate, primary-harness | No proof full visual animation quality or physical-device input. |
| 23 | `experiments/motion/entries/weapon_feel.tscn` | weapon-feel-entry, primary-harness | No proof full visual animation quality or physical-device input. |
| 24 | `experiments/motion/entries/weapon_feel_v2.tscn` | weapon-feel-v2-entry, primary-harness | No proof full visual animation quality or physical-device input. |
| 25 | `experiments/terrain/entries/basic.tscn` | primary-harness | Direct named-root startup separate; rendered/GPU image and user palette judgment not covered. |
| 26 | `experiments/terrain/entries/cavern.tscn` | primary-harness | Direct named-root startup separate; rendered/GPU image and user palette judgment not covered. |
| 27 | `experiments/terrain/entries/cavern_forest.tscn` | primary-harness | Direct named-root startup separate; rendered/GPU image and user palette judgment not covered. |
| 28 | `experiments/terrain/entries/cavern_gear.tscn` | primary-harness | Direct named-root startup separate; rendered/GPU image and user palette judgment not covered. |
| 29 | `experiments/terrain/entries/retro.tscn` | primary-harness | Direct named-root startup separate; rendered/GPU image and user palette judgment not covered. |
| 30 | `experiments/terrain/entries/scribble.tscn` | primary-harness | Direct named-root startup separate; rendered/GPU image and user palette judgment not covered. |
| 31 | `experiments/terrain/entries/style_lab.tscn` | primary-harness | Direct named-root startup separate; rendered/GPU image and user palette judgment not covered. |
| 32 | `experiments/terrain/entries/underworld.tscn` | primary-harness | Direct named-root startup separate; rendered/GPU image and user palette judgment not covered. |
| 33 | `experiments/terrain/entries/underworld_forest.tscn` | primary-harness | Direct named-root startup separate; rendered/GPU image and user palette judgment not covered. |
| 34 | `experiments/terrain/entries/underworld_gear.tscn` | primary-harness | Direct named-root startup separate; rendered/GPU image and user palette judgment not covered. |
| 35 | `experiments/motion/entries/graybox.tscn` | 没有现成精确交互runner | No existing precise Graybox RESET/contact/menu interactive runner found; shared motor/WorldContext core tests and startup do not prove this full legacy RESET policy. |

## 已有证据与最终待验

主树早先官方引擎已过：core/Bell/Forest restore、player-default/studio/blob/wind/pixel/style/cloud及entry owners/lifecycle等各自有限测试；JSON保留每项最后receipt，不签新优化引擎。Style已原生过20 routes/16 biomes，并包含4个命名PackedScene尾部断言；此前矩阵遗漏已纠正。

root启动诊断读取时已有25/38条结果，工作仍在进行；使用shutdown-C SHA c54ecbeb70aa099d3e985b6e3098b84540491c567578b0dce838ca0922f33311。这些是35入口加3模式，绝不是38交互验收。各条失败（若有）只记录该诊断范围。

明确保留：Graybox RESET/contact/menu缺精确交互runner；Home/Ambience Lab UI完整三模式/上下文未由共享adapter测试证明；PlainsPolishReview旧Boss8 fixture需独立原缺陷定性。有限native事件计数不签听感、GPU图像、手机/手柄、Web缓存/deep-link或完整自然通关。

所有带输出JSON的原motion runner拒绝覆写；重跑须用新目录，保留失败原件。不要加--quit-after、吞异常、改断言或放宽原budget。
