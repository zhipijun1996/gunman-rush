# 历史地图与 v12 默认消费者兼容

任务 FOREST-GRAPPLE-02。[原件包](raw.zip)、[逐文件 SHA 与范围](inventory.json)、[实际旧 v11 来源](../v11_fixture_provenance.json)、[权威加载账本](../authority.json)。本页只认地图重建、版本身份和声明的流程检查，不签钩索手感、关卡可玩性、趣味或设备认可。

首次 `grapple02-compat01` 实际 184 断言／8 失败保留：15% 配置变化使旧 v7/v9 的生成配置指纹漂移；两项 v11 预期误用了最终版之前的原件；两项七段主路 ID 尚未对应新几何。没有改写失败原件或旧 fixture。后两项预期改为实际明确的 v12 主路；v11 改用原始、源码绑定的最终语料完整 Manifest。

修复将 v1/v7/v9/v10 的历史**生成依据**固定为基线配置字节 SHA `e5161bb8ef1855b9eda515ab0613a4a738b47abc43b0f2dc118d2e45f71b2058`，v11 继承旧 v10。v12 在计算整体哈希前明确记录当前配置指纹。旧地图几何和哈希可重建；当前运行仍使用新版钩索和 15% 瞄准，不宣称旧二进制物理复现。

实际命令 `flock build/verification/engine.lock env GUNMAN_TOOLCHAIN_ROOT=/workspace/toolchains python3 tools/run_forest_depth_versions.py --output-dir build/forest_depth/versions/native/grapple02-compat02` 退出 0：196／0、14.053 秒、前后完整源清单一致。原 v1 实际 App 回退、v7/v9/v10 固定完整原件及两张最终 v11 完整原件保持；新版默认与显式 v12 完整输出一致，并拒绝未来版本、重新贴旧标签、错误 Boss、缺失动作边／停留环及混用配置指纹。schema3 历史 reader 保留；当前 CLI 使用新增 schema4。另对真实新 capture 做 20 个变造和 7 个同时修改显式／默认输出的语义反例，全部拒绝。

同一引擎锁下的原生入口依次实际通过：`tests/forest_progression_debug_runner.gd` 52／0（6.945 秒）、`tests/forest_progression_runner.gd` 29／0（1.711 秒）、`tests/forest_campaign_runner.gd` 51／0（7.507 秒）。保留原 180／90／180 秒预算和严格退出检查。后三项没有整树静默修改守卫；直接结算 fixture 仅证明流程，不证明玩家运动。版本检查的精确源绑定见原 receipt，不把之后的其他源码修改追认为已验证。

包内九份实现源码对应第二次通过时点；首次失败仅保留原始 capture、日志、receipt 和中间源码指纹，没有归档当时完整中间 verifier 字节，因此不声称该失败已具备独立重放的完整源码包。随后 `thorn_mouth` 候选又改动 v12 动作边身份；本页 196／0 是其之前的准确源检查点，不覆盖后续候选。
