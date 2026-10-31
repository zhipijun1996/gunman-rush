# 《失序之钟》AI 关卡设计体系 v1

任务 `AI-LEVEL-DESIGN-01`（工具与审计）及 `AI-LEVEL-PILOT-01`（隔离内容实验）。从 `main@e9ab0e0743466b8983e34cc7de17bab1abf9d53a` 独立开发，另在 `integration/four-lines-20261023@a074a709ffa64c1382d73d2dab6dcff673222728` 的真实运行源验证。新工具/候选为明确的源码覆盖层，由收据的完整实际字节清单绑定；基线 SHA 本身不冒充未提交覆盖层的唯一版本。

**本轮验证了有限的离线生成、真实物理、反证评价和失败回流方法；没有证明一般算法会无限创造有趣关卡，也没有晋级新内容到正式池。** 四层是设计语言，Macro 可选；Godot 继续使用现有 Module/森林/地图消费者。

## 选择的生成路线

离线 AI 创造和淘汰玩法家族，运行时在已验证前提内生成实例、组合与探索关系。优先积累优秀关系规则与少量成品，不追求庞大模块数量。有限样本通过不证明整个连续参数域成立。完全自由的runtime创造和本轮离线工厂不是同一能力。

Macro 只有在“子模块各自通过，仍不能推出整体资源、相位、分叉回程或节奏成立”时有价值。单个大场所、同一几何重命名、简单ID列表不自动升级；Map 可以直接使用 Cell/Module。

- [运行源审计](runtime_audit.md)：真实入口、生成器、Definition、Motor、Foundry、可复用链路与双基线差异。
- [177份来源审计](reference_audit.md)：逐项 SHA、导入范围、接入签名与能力声明缺口。
- [统一契约](contract.md)与[JSON Schema](content.schema.json)：四层、连接状态、能力/资源、来源与三轨证据。
- [模型实例与图的导出](model_examples.md)：177旧内容诚实保留未分解状态，新样本真实分解Cell；Macro来自真实itinerary，Map只绑定真实生成器而不伪造整图轨迹。
- [批量AI初审](batch_review.md)与[177逐项记录](library_reviews.json)：9份深入、168份有限源码初审，169份仍需要证据。
- [小样设计与早期失败](pilot_design.md)：版本、策略、源几何与证据边界。
- [用户参考图的设计推导及肉鸽生成取舍](reference_design.md)。
- [独立审查](independent_review.md)：原拒绝、反例、返工及最终限定范围。

## 关键审计结果

177 = 72资源 + 51森林结果/变体 + 36 Foundry短语 + 18连续路线。文档及固定源码来源完整一致；目录不是177种新机制。138份能力为partial、39份unspecified、0份defined；全部难度未校准。多端口和速度/冷却上限未完整进入编辑器能力摘要，原值仍保留。旧接入guard在两个新基线失配，必须重审，不等于真实消费者全部断开。

森林默认仍是v15，v18为独立开发入口。Foundry已有真实 Motor、全身危险扫掠、输入回放、有界失败与开发池；本轮复用这些消费者及原Harness，未另建正式运行系统。main双发且射击消耗精力，最新开发单发且使用时间能量；实际射击事件的次数与精力变化分别取证，不只更改标签。

## 评价怎样产生实际区别

| 内容/对照 | 实际观察 | 设计判断与边界 |
| --- | --- | --- |
| 长草甸 | 主路与去跳跃均可通行 | 休整角色合法，不能按动作少自动淘汰 |
| 低拱 | 去跳跃也通过 | 孤立模块不强制跳跃，不能凭名字/预设编舞称必需短跳；正式附加遭遇另验 |
| 森林基础草甸 | 本轮基础动作通过，去跳跃失败 | 只证明隔离几何，不证明整个森林无需钩索；保守能力声明不等于已证最低锁 |
| 平原高台选择 | 设计高路三跳；先走到奖台下再一跳也能到奖位 | 普通分路草案，三连动作的必要性被反证；保留合法替代，重想回报与观察价值 |
| 森林上下冠路 | 两路可走；从下根附近一跳也能直取同奖位 | 普通fork家族，不是已证新机制；不封低路强迫动作密码 |
| 根盆回原岸 | 原奖励路线455帧六跳；同几何删回原岸后319帧三跳 | 省136帧只属此bot策略；重复返程没有新状态/收益支持，优先重想或删冗余cycle |
| 回望宝藏 | 两轮有界修复后路线仍失败 | 停止本候选，保留失败、待重构；driver失败不等于物理不可能 |
| 8wu高度变体 | 同关系、同策略下落入相同测量家族 | 几何变化不自动制造新玩法；粗描述符相同也不是完整玩法等价证明 |

奖励实验只验证到达位置与返回标记，没有正式奖励实体、领取交易或保存证明。动态机关相位、钩索新机制、整图邻接、多Seed探索和真人趣味均不能从这轮几何小样推出。没有任何新候选被宣布“优秀模块”。

## 可运行闭环

```sh
# map-edit需检出审计记录中的固定提交；所有参考字节逐项核hash
python3 tools/level_content.py analyze --library ../map-edit --output build/ai_level_design_v1/library
python3 tools/level_content.py review --analysis build/ai_level_design_v1/library/analysis.json --reviews docs/ai_level_design_v1/library_reviews.json --output build/ai_level_design_v1/library/reviewed.json

# 三类原生策略，失败保留而非重标PASS；工具链固定Godot4.7.2 Standard
python3 tools/level_content_pilot.py --output build/ai_level_design_v1/pilot

# 明确有限可执行关系基因与同关系几何对照，依赖真实历史主/奖励路失败
python3 tools/level_content_search.py --feedback build/ai_level_design_v1/pilot/archive.json --output build/ai_level_design_v1/search --execute

python3 tools/level_content_export.py --analysis build/ai_level_design_v1/library/reviewed.json --pilot build/ai_level_design_v1/pilot/experiment.json --output build/ai_level_design_v1/model
python3 tools/level_content_contract.py build/ai_level_design_v1/model/bundle.json --root .

# 沿原Harness执行，非平行验收体系
python3 tools/harness.py --check ai-level-content --jobs 1
python3 tools/harness.py --check ai-level-pilot --jobs 1
python3 tools/production_plan.py --stage development --base origin/main --plan
```

AI初审是有作者、有来源hash的独立输入；CLI不把启发式计数冒充AI，更不调用隐含付费模型服务。此会话执行了设计与独审。无人值守的未来创作仍需接现有production_loop的AI宿主；仅运行上述CLI会生成/验证有限工厂和待审任务，不会自行获得真人趣味结论或训练出新模型。

## 证据与缓存

原生输出包含实际请求/接受事件、位置/速度、资源、唯一Motor步、端口、全身静态危险扫掠与终态。输入绑定真实catalog内容；缓存绑定完整实际源集合、严格runner、Godot二进制SHA/版本及原始输出日志SHA。少任何依赖、改输入、删轨迹或把拒绝改成通过都不能复用。多样性正档必须读取匹配的真实收据，独立sidecar技术通过也必须绑定完整outer ledger。

独审真实拒绝了初版“非空假轨迹入档”“缓存漏引擎/runner”“动态轨道ID/平移伪差异”“单sidecar缺core闭包”等缺口；原发现、修复、正反测试和新采集分开保留。用户/设备不能由AI或source hash代签。

早期v1/v2失败保留raw和hash，但当时未保存完整producer源字节，因此不宣称这些早轮完全可复现。最终轮提供完整实际文本源、固定Git基线、输入、原生日志/轨迹、逐成员SHA/CRC恢复索引；二进制美术从相同不可变Git基线恢复。本轮最终闭环可独立重建，不借当前实现解释旧源通过。

Development按已审计影响选最小原检查；未知依赖和共享边界仍保守升级，Release原检查完整保留。完整Release、正式地图准入及真人/设备认可没有被本轮技术样本代替。扩大规模前先改进并实测一个值得玩的关系家族。
