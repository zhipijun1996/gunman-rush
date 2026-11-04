# 交付提效（DELIVERY-EFFICIENCY-01）

2026-10-14用户授权按提效建议落实，并删除旧八小关。不是降低当前内容的验收标准。

## 删除边界

移除 DemoApp.start_plains_regression、RunProfile.formal8 与运行资源 formal_eight.tres。正式两张连通地区地图和三关开发样板保持独立。旧八关/十关存档明确拒绝，不能静默转换。14个依赖旧入口的测试源与旧资源移至 docs/archive/retired_eight，供历史证据追溯，Godot不导入、不在当前harness执行。

原43套分组混合旧App和共享消费者。剩余31套生成、真实Motor、相机、触屏、存档、Boss和家园检查通过 run_generated_consumer_tests.py 保留；旧命令只做兼容转发。核心回归移除两套旧八关流程，保留并更新profile拒绝、资源隔离、Boss不能绕过等通用断言。底层生成器、GeneratedDemoStage以及美术资源仍有地区/预览消费者，不按旧命名删除。

## 工作顺序

1. 把用户要求写成实际消费者与边界条件；先做一个完整动作样板。
2. 样板先经过原生Motor、真实浏览器多指、连续音画与移动附件检查；提前暴露触碰、墙边和瞄准问题。视觉/手感未认可不批量扩产。
3. 开发定位命令：`python3 tools/harness.py --check action-budget --check actor-actions --check studio-input --check all-weapons --jobs 4 --reuse`。报告明确标targeted_checks，不能代替完整交付。
4. 最终命令：`python3 tools/deliver.py --jobs 4`。查看执行顺序用 `--plan`，计划不算通过。
5. push/PR保持现有授权边界；CI全通过后才能发布；公开build-info还需与导出指纹一致。独立、真机与玩家签收分开记录。

## 并行与缓存

harness --jobs 4 为每条执行通道复制精确工作源，独立Godot导入缓存、user://数据、生成输出、配置与日志。导出与bundle消费有顺序依赖，保留串行。所有通道汇总，缺项、失败、超时、引擎错误、运行时源变化均不能通过。实际产物归集到报告旁artifacts目录。

--reuse仅在开发阶段启用。键包含实际输入文件内容/删除状态、检查规则、Python/Godot/Node版本。原生消费者的依赖保守覆盖scripts/scenes/resources/assets/config/tools/tests及项目配置；文档变化不使这些独立运行证明无效。其他检查不缓存；每次读取缓存重新验证日志Hash、成功标记、退出码与原证据目录。来源提交与input_digest保留，缓存命中不冒充本版本重新执行。

--release禁止复用缓存。CI和deliver使用该模式。工坊physics与presentation尚未证明可完全分离，继续保留原basis范围，避免错误复用路线证明；以并行和工具链缓存先消除等待。

## CI

工坊先生成一次并产出validated-foundry；core、Windows与Web在隔离runner并行消费同一批资源。发布依赖三个job全部成功。工具链下载缓存后仍检查版本。相同事件/ref的新提交取消过时流水线；push源与PR合并上下文仍分别验证，不把不同上下文当作相同证明。

## 自动交付边界

本地deliver依次执行工坊准备、完整玩法/美术、工坊原生、Windows、Web、三套真实浏览器操作与60FPS/48k立体声连续动作录像，将退出码/日志/构建指纹归集。任一步失败停止，不推送、不合并、不伪造真机验收。CI负责部署事务；公开版本核对、连续音画与独立审查按任务证据补充，工具不能把未执行项签成PASS。

首轮本地30项完整检查passed：558.073秒（含四路隔离准备），检查执行总量1070.1秒。此前串行记录1203.8秒；不同轮次/机器负载和移除旧流程均影响结果，不宣称全部来自并行。专项同依赖缓存命中命令0.85秒；最终release不复用。CI发布后自动核对公开metadata、HTML引用和pack内容Hash。

录像归集首次完整执行遇到样本字段不一致（weapon/demo），完整原视频已生成；只修复后处理解析并增加5个失败/覆盖用例，对同一视频重新验证通过，未重录冒充新源。原失败保留。追加capture-tests后完整profile为31项。独立审查仍待授权，Documentation审计未通过不能宣称整体交付done。

2026-10-14用户允许自主subagent、无需逐次授权，并授权合入main。独立审查先REJECT两个实际工具问题，修复后对98e7e11窄技术范围ACCEPT；R1动态新增源清单、R2正常退出遗留独立会话进程的反例/原失败/复审保留。AGENTS持久化授权；合并和部署继续执行，真机与主观维度不代签。
