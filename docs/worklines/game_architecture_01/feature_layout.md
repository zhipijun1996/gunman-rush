# GAME-ARCH-01 / P8 功能目录迁移候选

本批以 `986bb75d68213879366b824485f482e553158944` 为实际迁移源，将 1,124 个脚本、场景、资源和 UID 配对文件迁入功能目录；旧实现被移动，没有复制兼容包装类。`game/application` 负责入口与装配；玩家、战斗、装备、经济、奖励、进度、敌人、Boss、世界分别归入各自功能目录；共有表现归入 `game/presentation`，独立研究入口与专用实现归入 `experiments`。35 个既有入口保留，App 主入口变为 `game/application/demo.tscn`。当前导航文档由整合批次统一更新。

真正写入存档、Manifest 或 raw Definition SHA 的旧路径及必要脚本闭包保持原位，仍是唯一实现。16 份森林旧集成审计 JSON 保持旧位置和原字节，不能把其中历史指纹当运行配置搬迁。目录路径不是业务身份；模块 ID、存档键、生成随机算法和资源选择不改。Foundry 源版本因实际运行源迁移改变，须由既有 build/promote 流程生成新的技术来源，不能改签旧 basis 或声称旧 replay 已兼容。

本候选同时吸收已独立处理的历史 v11 charger Definition 修复（`549b8716`）、raw export 闭包（`9f4ae403`、`72299fb3`）、LevelRuntime 单向依赖整理（`cd71c538`）及 Bell 弹体 epoch 共享检查（`07c67561` 与修正 `448a9e09` 必须一起）。这些是明确列出的独立变更，不伪称全部差异只有路径替换。legacy charger 仍为 SHA256 `1afd5e34d497e3850d794b028fd5fe5407d3722fcd451d862f4c14a67ca98fc0`，其旧脚本 schema 引用保持原样。

11 份真实消费资产元数据只迁移当前消费者指针，相关技术记录更新元数据 SHA；旧原件按已有有限 archive manifest 保留。图像、音频、许可、原始来源字节未变；没有删除仍被实验、历史入口、回放或许可依赖的旧版本。旧资源的安全删除不能只依据“不是正式默认”；实际导出过滤与保留历史入口必须一起验证。当前资产记录的运行路径指向实际消费者，历史接受证据不作字符串替换。

静态验证：842 个源、510 个类、3,450 条依赖边，核心反向依赖与直接资源缺件均为零；118 个动态加载表达式仍明确未解析。全部搬移 UID 原字节一致，受保护源除上述独立 v11 修复外一致；除 11 个技术 JSON 外 assets 无变化。原项目结构检查通过；旧 style25 有限闭包测试 8 项通过。现有工具套件继续使用原 Harness 注册，不新增平行权威。当前旧 style25 / creative28 live 绑定仍待最终源码冻结后一次升级 style26 / creative29，不能用历史快照遮蔽 live 漂移。

Godot、完整原生回归、Foundry 重建、真实 PCK 和入口实测由整合租约执行，本批静态通过不等于这些检查通过。源码工作树仍需等真实泄漏问题修复与独审收口后冻结技术绑定。候选可整体回退至迁移前源提交；工具闭包与运行迁移是一个完整批次，不能单独合入 `5589c284` 工具半套。

外部可检索交付位于 `/workspace/refactor-evidence/`：`feature-layout-execution.json` 保存逐文件映射与协议持有理由；`feature-layout-static-integrity-final-candidate.json` 保存逐字验证结果；`feature-layout-approved-fixes.json` 保存独立修复整合记录；`feature-layout-asset-metadata-rebinding.json` 保存元数据精确改动；`repository-file-index-candidate.jsonl` 与 `.csv` 为全部 tracked 文件及本候选新增文件的用途、归属、可能入口与依赖索引。索引是审计报告，不是第二套运行注册表；稀疏未物化文件不为扫描下载媒体字节。
