# GAME-ARCH-01 / P8.1：有限旧源冻结

本批只为后续功能目录迁移保留真实旧源，不搬运行文件，不更新当前 style25 / creative28，也不继承旧艺术、玩法、音频、用户或设备接受。

原始来源固定为 `4bb7aa962cb9477b6fc931b221b3a38132cad1f2`。归档在 `docs/creative_direction/archive/feature-layout-before-style26/`，沿用已有 `manifest.sources` / `manifest.files` 格式：72 个将迁移的 style25 引用源、1 个 style1–4 仍读取的旧 shader，加原 registry、style25、两区 creative28、两份原测试和原 Harness profiles。80 个原文件逐字与原 Git blob 比较一致；共 1,466,647 字节（含 manifest），不复制图声或 UID。

四个 style 引用的 Boss 资源/场景仍保持原协议路径，因此本批不重复归档。其余媒体、配置、原 Bible 和用户方向证据继续使用既有权威原件。73 个源以 `.txt` 保存，避免再次注册旧运行类。旧 manifest、旧 SHA 和旧失败不修改。

两份现有 Bible 测试共用 `tools/region_style_history.py` 的原 manifest 取源/验 SHA 算法；各 Boss 父快照仍优先，随后才读取本次明确列出的旧源。未列入归档的依赖保持 live；已列入但丢失或损坏的旧源必须报错，不能退回 live。该 adapter 仅被历史测试调用，当前 `region_creative_direction` 绑定验证不调用它。没有新增 CI check 或运行时 registry。

已执行 `python3 tests/test_region_bible.py Style25ArchiveTests`：7 项通过。覆盖源闭包、80 个文件指纹、全部旧测试方法 AST 原样保留、缺件/损坏/修改 manifest 拒绝、旧父源优先，以及存在旧归档时 live 源漂移仍被拒绝。

当前 `python3 tools/region_creative_direction.py --check-bibles` 仍因 `scripts/demo/demo_app.gd` 的既有源字节变化失败。这不是本批新增漂移，也不能用归档将当前状态改签为通过。完整原测试、Godot、实际入口与导出未在本批执行。

P8.2 须等待 P3/P5/P6/P7 整合后刷新逐文件映射。保留已标记的 226 个协议路径；`PlatformingModuleDefinition` 本身未导出场景路径，而 `RandomStageGenerator.scene_for()` 按原模块 ID 装载场景。其 `content_hash()` 排除 `script/resource_path`，但 Foundry 的 basis 与其他生成器还直接绑定源文件路径/字节，不能仅凭 content_hash 不变就移动场景。模块资源/场景及所有旧 Manifest 身份在证明真实重放兼容前保持原位。

后续一次升到 style26 / creative29 时只绑定冻结后的当前真实消费者。有限归档不能替代新绑定检查；两份既有 Bible 检查 inputs 需追加本归档目录及 `tools/region_style_history.py`，不新增平行检查。回退使用本批提交的 revert；本批父提交为 `7a7883a36fdec904de850aced81cf54fa1d0ff8b`。
