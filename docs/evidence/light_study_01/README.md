# LIGHT-STUDY-01：家园／平原光感快速实验

2026-10-22，用户要求基于现有家园与平原快速做更明亮、不压抑的方向实机图，明确不跑 CI。三候选仅显式 Lab 生效，不替换默认入口，也不晋级全局风格。基线 `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`，独立分支 `art/light-study`。

写集所有者 root：`scripts/art/light_study.gd`、`shaders/light_study.gdshader`、`scenes/dev/light_study.tscn` 及本任务证据。无 Definition、物理、生成、存档、正式素材、公共配置或现有 UID 修改。沿用 visual-director / art-director 的实机分层与独立看图要求；依本次用户明确指令简化生产流程。完整记录见 [LIGHT-STUDY-01](../../quality/records/LIGHT-STUDY-01.json)。

直接运行：`bash tools/godot.sh --path . scenes/dev/light_study.tscn`。底部按钮可切 ORIGINAL / DAWN / JADE / LILAC 与 HOME / PLAINS；默认游戏入口不变，实验 Meta 持久化禁用。

截图命令见质量记录。正式 DemoApp、HomeScene、PlainsRegionStage、真实 UI 与对象均保留；位置明确设置后冻结物理与表现回调。同一窗口各候选复用角色姿态、相机与 Seed，背景位置变化属于候选美术。共四窗口 × 四版本 = 16 张原始 1280×720 PNG；本目录精选家园与平原出生点八张，全部路径与位置见 [capture.json](capture.json)。不是自然移动／通关证据；截图不做后期调色。

- A 晨光：青蓝晨空、奶油地平线、提高石体与建筑明度，压低暗部碎点；推荐作为默认继续探索。
- B 青绿：深蓝石体、青绿草边、暖黄建筑；推荐局部神秘空间，仍缺少完整亮源／反光关系。
- C 蓝紫：紫蓝阴影、杏粉天空、冷绿草边；更柔和，独特性次于前两版。

独立只读代理实际看 final 五图，确认方向改善，保留草边整齐荧光线、缺少邻近反光、青绿标签对比偏低的意见；不签定稿、玩法、用户认可或真机。原生最终退出 0、16 张完成标记见 [capture.log](capture.log)。本轮未跑 CI/Harness、全玩法回归或 Web 导出／发布。

失败保留：首轮天空平带／碎点见 `build/light_study`；第二轮 UI 初始化未完成即冻结导致 Boss 模板残留，保留 `build/light_study_v2`；首次 final 的 RefCounted 类型判断 parse 失败见 [failed_parse.log](failed_parse.log)。改成真实嵌套 CanvasItem 类型并等待真实 process_frame 后重采 final，不将旧失败签通过。

交付另有离线自包含 `comparison.html`，支持四镜头／三方向与原版拖动对照，以及两张对照板；它是截图查看器，并非可玩 Web。下一步由用户看图选择，再投入局部亮源、反射、草边疏密与地形材质体积；当前只完成本轮方向实验。
