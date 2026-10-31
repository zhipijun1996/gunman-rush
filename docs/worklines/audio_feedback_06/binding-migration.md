# AUDIO-FEEDBACK-06：标题字幕恢复的有限技术重绑

本轮实际音频修订移除 `DemoMenu.TitleEnableMusic`，标题回到原字幕 Label。不是新画风、像素制作或地区方向。当前冻结 style20 绑定了实际菜单源码，原 `region_creative_direction.py --check-bibles` 已因该路径 SHA 漂移真实退出1；日志和精确收据在 `build/audio_feedback_06/binding-migration/bible-before-02.log`、`migration-audit.json`。不能用刷新 style20 或回退整个 style19 代替迁移：当前 DemoApp 和 shop 仍保留 style20 的已接入音频消费者源码。

因此沿既有机制新增 [style21](../../creative_direction/bibles/style-continuity-20261030-v21-audio-feedback-06.json)，两区当前总谱技术版本为 creative-v24。只重绑以下一个实际消费者：

| role / path | style20 SHA256 | style21 SHA256 |
| --- | --- | --- |
| `item_pause_menu` / `scripts/ui/demo_menu.gd` | `af2f5a92ca800bcbe4340c23d3007e9d37b93dff96e9720df102cb17040c930d` | `1552093205becf49569ae581747e4f8d71fc6f5b1552d021bb0aa7490f95471f` |

81项 role/path/顺序不变，另80项完整逐项相同。恢复菜单的完整字节与 [creative22 中的原字幕版本](../../creative_direction/archive/creative-v22/runtime_inputs/demo_menu.gd.txt) 一致，不只是某一字幕字符串相同。没有将 DemoApp/shop 或其余源码退回旧版。

[creative23 归档 manifest](../../creative_direction/archive/creative-v23/manifest.json) 保存旧 registry、两区总谱及菜单手势版 `.gd.txt`，均由基线 `f0778c4c9e14e5cb05a63cf5e027da011a63db54` 的实际原件核 SHA。style20 原文件 SHA 保持 `66d75a2ea49cf0126cfbe5585daf2099ec3b1e883e8b5cd01e5ff78b77ac92f8`；归档 manifest SHA 为 `d4d6c6026932c114c0f24e54b7008069b74f11b43065e03e3d1343134e450e96`。新 style21 SHA 为 `2f6e92fac7c82122ac3e9e7e0593f19750424e0a4c0a0636631a5fb2af2e73de`。

registry 只改变 `shared_style_authority`；16区清单、用户指令、两份原区域 Bible 和原选择证据字节不变。两区总谱只改变技术版本、绑定的 registry/style SHA、追加新 style 来源和本次影响说明，其他方向字段保留。GameMusic、SelectedSfxRuntime、WeaponAudioV2 与 hurt06 的音频生产修改不在本技术迁移的写集或验收结论内。

## 原检查保持与最小增量

- `tests/test_region_bible.py`：旧34方法全部保留，新增1个有限style20→21正反例，共35方法。静态 assert 调用332→358；每个旧方法的断言调用数均未减少。style19→20的原比较读取真实冻结style20及手势菜单源码，不再误把当前恢复菜单当历史style20源。
- `tests/test_region_creative_direction.py`：旧12方法全部保留，新增1个creative23→24正反例，共13方法。静态 assert 调用155→168；每个旧方法断言调用数未减少。creative22→23比较读取冻结creative23，正式任务路由期望更新为creative24。
- 原 Harness `region-bible-tests` 的331个输入顺序完整保留，仅在尾部追加6个实际读取的新style/归档文件至337；命令、30秒预算、权重和成功标记均未改。未添加另一个门禁或扩大美术profile。
- 新反例包含旧style20/creative23指针拒绝，以及隔离fixture中真实菜单字节漂移拒绝、恢复后重新绑定。未修改正式菜单制造测试失败。

本代理实际执行了变更前绑定拒绝、离线差异核对、AST方法/断言保留检查、Python语法编译及 `git diff --check`。未运行Godot、完整Python套件或导出；引擎租约及实际回归和独立审查由root统一安排。以下原入口应按本轮真实运行结果另记，本文不把计划写为通过：

```sh
python3 tests/test_region_bible.py
python3 tests/test_region_creative_direction.py
python3 tools/region_creative_direction.py --check-bibles
python3 tools/region_creative_direction.py docs/creative_direction/windchime_plains.json docs/creative_direction/thorn_forest.json
```

本迁移只说明创作来源绑定的技术身份和可重复拒绝能力。没有生成美术、改变32px/32wu或1wu nearest、签实体设备、用户听感、视觉品质、完整G5，亦不继承旧版本验收。旧失败和冻结原件均保留。
