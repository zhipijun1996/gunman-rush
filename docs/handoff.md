# 最新交接：探索场所原型 v18

2026-10-22，分支 `feature/region-bible-v2-forest`，草稿 [PR101](https://github.com/zhipijun1996/gunman-rush/pull/101) 未合 main。准确提交以 Git 为准。公开仍[旧 v15](current_state.md#当前公开试玩)，不能把旧 build12ac 说成本轮。

## 已实现和边界

用户已选每图正常8–12分钟、充分探索15–20分钟作为初步真人目标；没有真人计时，不能用原生帧数换算。v18 新显式 FOREST PLACES 入口保留 v15 核心／早段休整根／HH和螺旋技巧线，加入双窗、7型高枝回落、Z内外折返、倒木上下路，图二另有固定果 H＋反向射击背枝。真正root Seed改变Z／倒木顺序，两图反排；Boss完整factory后移到最终出口。真实奖励为金币或音符二选一且幂等，没有清空支线开门锁。

当前仍是带多处分流汇流的场所链，非充分网状森林，也不是完整模块库。活果渡口未实现；固定果不冒称活目标。森林含美术优先，平原仍planned；BGM未生成或替换。普通森林 default15 与历史producer保留，没有修改Motor／物理／资源／能力／保存。

## 实际失败与继续点

原33项在600秒超时，29项完成不能追认为整轮通过。App04独审拒绝Fallen巨L；18.3真实西根外弯、东根凹窝及心木底面已改，App05八张源稳定且独审确认有实质改善，只允许继续候选通行验证，未签ART。Z的细悬臂／倒L、Back浮空平楔／通屏夹层、倒木长地板和木质识别仍待定稿。两条失败材质方向完整归档，未进入runtime。不能再用纹理、更多变体或测试计数覆盖构图失败，不能把原型覆盖旧公开包。

新开发反馈分成 `python3 tools/harness.py --profile forest-places-feedback --release --jobs 1`（core20）和 `--profile forest-library-feedback`（library16）。根据改动选，不每次部署整套；保90import/240native/600whole、fixed60、串行引擎和严格非空／完整输入／完整脚／OR结算守卫。旧80/full/CI未改，本轮没有重签完整CI。

精选原始源码、全轨迹、失败、静图、独审和每成员完整SHA在[证据索引](evidence/forest_variety_04/README.md)；当前质量状态见[记录](quality/records/FOREST-VARIETY-04.json)。新浏览器 `--forest-places` 只实际OCR点击候选入口并校验组装18，默认四入口不变；只验GUI，不签奖励／手感。

## 操作与存储

root唯一Godot/import/GPU/browser租约；运行源与Git冻结期间禁止并行写生产。只用 `bash tools/godot.sh` / Godot4.7.2 Standard。不动 `/workspace/gunman-rush-ci-H`、原始附件、`.git/.godot` 或历史失败。audit SHA保持 `c47e366e9fbc1e3584a7c7e3eb8b983422156e21eb420a34456a2d8eb7219791`。

先 `df -h /workspace /tmp`。旧564份大JSON以完整字节/SHA读回验证后可逆存于 `build/storage-preservation-20261022/large-json-lossless.zip`，旁有RESTORE-INDEX.json；旧平原run_vs12o4rc原件同目录lossless.zip和RESTORE-INDEX.json。不是删除不可恢复证据。运行时快照仅复制实际源与必要资产，不复制海量历史build。

合入/完整交付另跑适用原profile。新试玩按已有快速流程复用同源已验包或仅Web重建和必要检查；当前艺术未过，不以新原型替换旧公开包。完成更多有趣机制与网状拓扑后再验人类时长、手感、手机性能和玩家认可。

本轮最终新库16项inner／outer均exit0，334.075秒；新倒木之后两图正式主路线分别55.099／79.963秒通过，整轮135.791秒，源稳定。不是fresh完整core20、原80或fullCI。静图是明确摆位fixture，不作自然游玩／动态证据。

文档／流程29项fresh通过；具体证据路径已普通Git归档。PR实际base仍7be8c340372d1e20db6685cbd6a559191821eb0e，需保持差异与commit-tree证据闭包检查。
