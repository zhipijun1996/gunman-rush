# 正式平原试玩修复验证

[公开试玩](https://zhipijun1996.github.io/gunman-rush/?build=f78b51be4131)版本 `f78b51be4131`，来源 `81a6b222e7cca64bcf0aecf01060e9e649176097`。完整线上PCK的长度和SHA256与本地导出一致，见 [部署凭据](playtest_deployment.json)。

正式参数为两图各三条主通路、六处奖励，使用家园实际角色能力。SDK0.4.1与模块包1.1.0保持原件；69模块池及搜索参数由 `config/plains_mapgen.json` 维护。

## 输入核对

开发切片的默认 `conformance` 输入是SDK一致性夹具，不能当成真实玩家能力；其 `controller` 模式才投影实际角色。正式流程始终读取出发角色，已提交地图的重装不重新抽图。

| 输入 | 对照正式版本 | SDK一致性／默认开发样例 | 当前正式版本 |
| --- | --- | --- | --- |
| 模块池 | 44，整模块排除纵向Port | 无正式白名单 | 69，移除纵向Port这一排除原因；其余37个保留具体未绑定原因 |
| 能力 | 实际基础jump／shot_recoil | jump／double_jump／shot_recoil／grapple，仅算法输入 | 实际Controller、碰撞体、装备及已授予能力；不照抄夹具 |
| 生长／主路／奖励 | 两图20／24生长、1主路、4奖励 | 32生长、3主路、6奖励 | 两图32／36生长、3主路、6奖励 |
| 形态 | target_ratio=3、max_aspect=8 | target_ratio=1.5、max_aspect=3 | 使用二维形态约束，恢复纵向变化 |
| AIR循环 | 关闭 | 开启 | 开启，仍受实际能力筛选 |

当前输入以 [正式配置](../../../config/plains_mapgen.json)为机器可读来源。锁定的 [一致性请求](../../../resources/mapgen/conformance_request.json)与 [SDK配置](../../../resources/mapgen/generator_config.json)保持原件；正式宿主显式投影和覆盖，不改写上游夹具。

## 地图与重复统计

同一组六种子、两图、基础脉冲枪，对照基线 `83ad40b9ecd48e399914f0b0b0a37d57c12bc390`。图中绘制SDK实际平台与封口，未绘制节点连线；为了比较整图，证据图不加玩家探索迷雾。

- [第一图对照](map_1_comparison.png)、[第二图对照](map_2_comparison.png)、[逐图参数与分阶段观测](corpus_report.json)。
- 成功装配10/12 → 12/12；失败尝试30 → 6；实际纵向接缝平均0 → 12.17。
- 平均模块种类16.3 → 24.25；四类常见连接模块占比55.73% → 29.31%。地图扩大后，全部重复实例占比52.30% → 56.37%，没有把这项增加隐藏为“完全去重”。
- 原生无图形采样的等待中位数4.05 → 8.15秒、最大47.11 → 37.36秒。新目标增加了求解量；这不是网页帧率或设备性能承诺。分阶段数据保留失败重试，提前预载成本也单独记录。

复现采样：`bash tools/godot.sh --headless --audio-driver Dummy --fixed-fps 60 --path . --script tools/mapgen_plains_review.gd -- --output=res://build/mapgen_review/current`。两图中的第二图为显式测量夹具；不把它称为从第一图自然抵达第二图。

## 原生与网页检查

公开桌面Chromium已从标题、家园菜单正式出发进入 `ci-smoke`，非调试入口，实际地图哈希与原生相同，无页面脚本错误。点击出发至进入地图16.834秒；前一公开构建同种子观测45.97秒。此次预载剩余等待1.409秒、后台求解13.278秒、失败重试0秒、验证0.213秒、绑定／装配1.343秒；场景内单调时钟总计16.307秒，浏览器总观测另含输入与轮询间隔。标题／家园预载完整观测14.854秒，包含逐帧让出时间，已单列而未冒充零成本。初始Web包下载不计入点击出发后的生成等待。另在公开版本的后台求解开始后点击返回家园，确认结算／家园界面恢复、无旧地图迟到提交和页面脚本错误，见 [取消报告](public_cancel_report.json)。

[正式画面与HUD缩略图](public_plains.png)、[实际地形展开图](public_map.png)、[浏览器报告](public_report.json)保留公开版本结果；不是实体设备或浏览器完整战役通关的证明。

`python3 tools/check_mapgen_formal_plains.py`覆盖正式流程71项、实际生成模块接缝6项，以及 `formal-integration-1` 的连续输入路线：2366物理帧内到达Boss并造成1点有效弱点伤害，重装保留39HP和安全入口。路线没有中途位置、生命、速度或能力写入。

[接缝轨迹](native_seams.json)使用真实生成的两个模块、原几何和自动Controller／Motor，覆盖上穿、落脚、主动下穿及横向跨缝。每个隔离夹具只有一次初始出生设置；没有把这些检查扩称为全部种子的全图物理认证。[连续路线轨迹](route_trace.json)保留对应输入和身体观测。正式流程中的Boss结算和奖励事务仍含明确的位置／伤害夹具，不代表两Boss自然实战通关。

四项日常CI、文档、生成作业生命周期、来源身份、既有开发切片和风铃消费者通过。工坊重新验证36路线、18连续行程，刷新正式导出依据。网页HUD和展开地图均使用真实平台、开口、共享探索迷雾与玩家标记；HUD以玩家附近地形为视野，展开图支持整图、缩放和平移。

## 上游请求

[可复现输入](upstream_repro.json)包含真实基础能力、完整筛选池、原始请求和配置、SDK／模块包身份及500001候选耗尽结果。命令：

`bash tools/godot.sh --headless --audio-driver Dummy --fixed-fps 60 --path . --script tools/mapgen_plains_review.gd -- --output=res://build/mapgen_review/upstream --repro=res://docs/evidence/mapgen_plains_playtest_fixes/upstream_repro.json`

已提交 [map-gen #7](https://github.com/zhipijun1996/map-gen/issues/7)。该命令直接运行原SDK，复现闭环搜索预算耗尽；宿主不修改算法、不降低主路／奖励目标。需要上游优化基础能力下的闭环、Boss与奖励预留搜索，并提供覆盖实际动作预算和跨模块接缝的物理资格。H／D、组运动、成对门等未绑定内容仍不作为已交付能力。
