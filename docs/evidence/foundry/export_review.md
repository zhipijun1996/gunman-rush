# 导出与范围独立审查

2026-10-12；独立代理 foundry_export_review。只读检查实现、配置、流水线、录像分析与已有证据，检查实际 Web 截图；未重新运行全套测试，未修改业务代码。

## 初审结论：需修复版本指纹覆盖

- Web 导出消费者已实际加载：`build/verification/foundry-browser/lab-fixed.png` 展示中文工坊 UI、基础能力配置、六类片段选择、角色和真实场景。相比仅检查打包文件，此证据足以排除“所有批次在导出后为空”；未独立证明所有 Web 回放都已跑完。
- 三个平台 export_presets 均显式包含工坊配置、batch、replays、export_basis JSON。官方 `tools/build.py` 在导出之前调用 stamp，stamp 先在源工程检查 batch.basis；因此已覆盖的源代码变化会拒绝导出，不能仅靠旧 stamp 掩盖。导出运行时校验引擎和配置后信任 stamp，以避免编译脚本与源脚本 hash 不同。
- **需修复**：`FoundryCatalog.basis()` 未覆盖 `scripts/resources`、`scripts/damage` 和 `scripts/run/demo_lifetime.gd`。例如射击精力默认策略来自 `scripts/resources/definitions/shot_energy_definition.gd`，更改其中默认消耗/恢复值会改变已验证动作的资源资格，却不改变旧 basis。伤害、死亡和段回退同样属于已宣称的验证依赖。应覆盖这些运行依赖后重建批次、重跑消费者、重新 stamp 与导出。
- 文档应说明支持的导出入口为 `tools/build.py`。手动 Godot export 不会自动执行 stamp，带着旧 stamp 导出变更代码不能获得同等 freshness 保证；这不是加密或防篡改机制。

## 范围与诚实性

文档明确四款游戏只采样有限片段，保留 YouTube 403 与丝之歌片段长度不足；分析区分观察、推论、未验证项目，没有冒称完整游戏逐帧学习。CLI 提供下载、机械生成验证和 AI 任务队列，未声称持续后台大模型已连接。

36 段是六种结构的现有机关组合、相位和能力兼容变体，不是 36 种独立机制。二跳/四发未宣称专属四发动作链；钩子未实现且禁用。趣味性/美术/手感保持 awaiting-device，正式平原池未扩入本轮新内容。上述表述诚实，与目前证据一致。

首轮否决、移动平台回放入口修复及独立六模板回放 0 误差证据均保留。修复版本指纹覆盖后可通过本项技术审查；不能以本审查代替用户趣味性认可或线上发布验证。

## 复审结论：阻塞已修复，代码与批次审查通过

已只读复查新增 `_add_basis_tree`：递归包含 `scripts/damage`、`scripts/resources`、`scripts/run`、`resources/player` 的 `.gd` / `.tres` 文件，覆盖初审指出的精力默认值、资源状态、伤害/回退和生命周期依赖。文件排序、去重后纳入源 hash，未放宽旧批次校验。上述初审否决保留。

复查当前已安装与构建批次均为 basis `c114ff83f498b0683b0c30223104f17987f071dcebaceb1e7e88716fbb8361de`，36 段、18 条整段路线/连接证明；三能力配置日志均 failures=0。当前 export_basis 与该 basis 一致。文档明确只有 `tools/build.py` 导出路径具备源码新鲜度保证。

本项源码、导出契约及批次复审通过。最终消费者回归和重新 Web 导出的执行结果由主代理记录；本复审没有冒称独立执行这两项，也没有把前一版浏览器截图当新包验收。最终公开试玩仍需核对实际已发布版本，趣味性/设备保持待用户试玩。
