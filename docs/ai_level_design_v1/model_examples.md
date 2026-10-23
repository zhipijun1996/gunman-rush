# 四层实例与设计图导出

`tools/level_content_export.py` 把已核验来源的分析报告和同源原生轨迹解释为设计 sidecar；输出始终留在 `build/`，不写 Godot 场景、资源、模块池或正式地图入口。

```sh
python3 tools/level_content_export.py \
  --analysis build/ai_level_design_v1/library/reviewed.json \
  --pilot build/ai_level_design_v1/pilot-main-final/experiment.json \
  --output build/ai_level_design_v1/model-export
python3 tools/level_content_contract.py build/ai_level_design_v1/model-export/bundle.json --root .
```

输入分析报告的 `modules` 保存 source/features/ai_design；物理实验的 `results` 用 `raw_path/raw_sha256` 指向原生数据。导出器重新核对原件字节，并调用同一 `validate_bundle(..., root)`，不把 wrapper 的绿色标签当物理证明。来源、producer、catalog、tuning、候选身份和实际输入须满足原契约的窄适配。

最终版技术通过还附原生raw对应outer ledger，核完整依赖集合与当前实际字节；只附旧raw或删去Controller依赖、重绑外层hash均拒绝。图中挑选完整 `reward` 轨迹；新增 `near_reward` 的一跳直取单独作为设计反证，不能冒充完整回程。

177 份旧参考保留 `legacy_atomic`。其 source_feature_summary 记录原文档 SHA、实体计数和未解释的原端口合同，不冒称已完成 Cell 分解，也不以导入覆盖代签最低能力、物理或趣味。AI 源码初审与真人字段分别保留；旧消费者指纹漂移后，当前接入声明维持 `unverified`。

四份新小样从真实 Definition 的矩形尺寸和同 SHA 工厂显式的单向支承数组生成 Cell，再以真实位置作为 Module 中的 `parts.offset`。Cell 是这份已采样构造的接触面实例，不声称参数范围内每种尺寸都已经验证。Module 的主路、支路和回程来自原生路线；端口是单次运行的实际状态采样，不能当完整可接续包络。技术 `passed` 仅用于主路和奖励位置往返均有同源成功原件的候选；其余正向失败保留 `failed/rework`。所有候选均未验证正式领奖交易、艺术定稿、真人趣味或设备手感。

SVG 分开显示蓝色虚线主路、金色虚线设计支路/回程、绿色真实轨迹。虚线跨越不是物理运动，绿色采样也不是录像；图中奖励只是 reachability marker。失败候选继续显示真实失败轨迹，不会替换成成功示意。

Macro 样例取 `resources/foundry/batch.json` 的一条真实 itinerary，按原 nodes/offsets 引用已有 Module，保留 phrase boundaries、manifest hash 和能力 profile。运行继续交原 FoundryWorld；这只是跨片连续责任的设计解释，不新增 Macro 节点，也不把旧 batch 标签重签为本轮 fresh 物理。

Map 样例绑定真实 PlainsRegionGenerator 与 PlainsRegionAssembler。导出器不启动整图生成，所以保留 `legacy_atomic`、空实例拓扑与未验技术状态，不虚构 Seed 或探索图。这个例子说明四层语言能指向正式消费者，同时诚实表达尚未提取的内容；它不替代原地区 Manifest。Map 可直接使用 Module/Cell，Macro 仍是可选的跨片合同。

本轮实例用于证明数据语言、来源约束及证据分轨可以落到现有对象。它们不是增加内容数量的生产成果，也不授予正式池准入。
