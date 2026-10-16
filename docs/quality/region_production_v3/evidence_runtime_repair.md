# V3 实际证据链修复（集成范围）

任务 `V3-EVIDENCE-RELIABILITY-01`，继承原 G0–G5；不是森林包第三轮，也不重写其两轮 REJECT。实际主 Codex 实施与不同代理只读审查分开记录。

## 已复现的失败

1. 同仓库相对路径的正式影片从 scene 工作树归档到根工作树，原 `compare` 实际 exit2：`unexpected real producer command`。唯一不同为真实 MovieWriter 的绝对输出目录；原日志仍记录原工作树。原影片、请求、日志、失败 receipt 不改。
2. 长驻生产控制器第一轮 `import level_design_contracts` 后缓存旧函数，第二轮虽修磁盘合同仍可能使用旧验收器。森林严格修复证据来自新的独立进程，不能称旧控制器已热加载。
3. 森林 R2 独审实际以 euid1000 + chmod000 目录复现：`os.walk` 默认静默跳过不可读目录，UID清理误判无引用。森林原包最终 REJECT；根集成另修并重新验证。
4. 正式 observer 提供真实 `middle_far` 景层，但旧 composition adapter 枚举不接受。实际 `/08` native 正常完成 3090 ticks / 3094 movie frames，adapter FAILED；保留原 AVI，仅恢复后处理。

## 修复边界

跨工作树只允许 MovieWriter 绝对前缀差异；仓库相对尾部、其他全部 argv、原生完成日志原目的地、源码和媒体绑定继续严格验证。相对路径、不同文件、非规范路径、其他 argv、更换 root、缺失/错误/重复原生目的地都拒绝。这不是对伪造原生进程的认证服务。

每次 region 验收重新从当前磁盘加载契约与源码清单实现，保留第一轮失败。UID 处理采用未知即保留，根集成选用首次真实 import 的整对 UID 原字节。真实 `middle_far` 只扩展已实际存在的层语义，未知层仍拒绝；bounds 仍不能证明景深或美感。

后处理恢复不调用 Godot，原 FAILED 保持。根新 `layers_map2_seed08_fast_finalized_v1` 已真实生成 MP4/抽帧/composition，并通过 inspect；原失败 SHA `9f898c7fb846344144da8a2f91f74e142b8c5cd7e00cf58de59f7648f2ee2a55` 未变。该次 adapter 源随后修改了路由约束字符串，已以精确 SHA 验证逆向恢复保存 `build/region_production_v3/reliability/finalizer_executed_source.py`，明确是 verified_reconstruction；未来 finalize 在开始时直接归档其代码，避免活文件引用漂移。

现有路由与五个专业 Skills 同步修正旧全局黄金锁：失败母版只阻塞其自身依赖；不同已合格家族继续。不同有限用途另列实际消费者与像素审查，原合同失败不能追认或降低阈值。

## 当前实际检查

- `python3 -m unittest discover -s tests -p test_visual_director.py`：17 tests，通过；保留原断言，增加跨工作树命令/原生日志正反例及 middle_far/未知层对照。
- `python3 -m unittest discover -s tests -p test_production_loop.py`：55 tests，通过；临时项目真实改写磁盘代码验证两轮加载，旧函数仍返回旧结果而新调用读取修复。上述单测明确不冒充模型/Godot生产。
- 原静态基线 vs 初轮 growth 影片实际 `compare`：`comparable_for_review`；同 Seed/map/策略/能力/driver/core/Manifest，不是逐像素配准或趣味证明。
- 独立实际反例进一步暴露 adapter 引用未消费及本地命令 early-return 未核原日志；新 adaptation version2 强制归档代码/原错误/原 raw/计算来源，旧版明确 adapter_identity=unverified，删除 adaptation 不能继承自报验证。两分支现在均要求唯一原生 MovieWriter 完成目的地匹配；ROOT新 v2 后处理再次真实完成，原 v1/FAILED 不变，严格 inspect/compare 通过。
- ROOT fresh 森林/UID反例与独审另补；技术通过不签商业、真人、音轨听审或实体设备性能。

原生影片期间重型引擎串行；后处理恢复不重复消耗已经有效的游戏输入运行。
