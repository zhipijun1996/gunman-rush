# creative-v3：整合后的创作合同重审

2026-10-19，PARALLEL-INTEGRATION-01。不是新美术制作或新玩法验收；沿region-creative-director的RETHINK与既有schema 1，重新审查当前消费者和最新授权。旧CI39232313993的routing失败及原ZIP不改签。

## 为什么旧合同不能只更新SHA

两个active v2均绑定20%调优和旧输入合同；当前已授权15%枪/钩瞄准、按住松手发钩、真实碰撞斜下拉与稳定小踢、可停留环。森林仍写“仅技术样板、未开放、敌人/Boss未制作”，与现行可玩v12不符。平原将旧手绘空间GoldenStage写作当前唯一制作方向，却未消费PR91最新用户像素小样反馈与全区授权。只刷新两项hash会将旧意图、旧证据错误签给新源。

本次不改Motor、玩家身体、射程、资源、保存、验证器、发布或quality门槛；不改已有正反例，只将当前版本断言v2→v3并增加旧bytes/拒绝断言。

## 决策与当前来源

- 平原：保留逆风送钟世界主题，重新比较当前quiet pixel、独立源画场所、已拒暖砌石三种方向。正式默认选择PR91 `2f25083da11da11604a3535a2feae20d119ac001`，历史已发布游戏为`c0f8e50770145795db5affd4afdbffff2479f1ea`。引用实际[user_request.txt](../evidence/windchime_pixel_01/user_request.txt)与[交付身份](../evidence/windchime_pixel_01/delivery.json)。小样方向认可授权制作整区，不等于最终两图审美通过。PR90源画及旧手绘候选只显式native，不继承用户确认也不覆盖默认。旧暖色用户REJECT继续有效。
- 森林：比较纵向树洞/横向棘口/枝冠连续换向、旧等待开合、全刺固定连招。选择第一种当前v12已实现方向；第三种以负担代决策，淘汰。实际来源为[本轮动作与空间合同](../design/forest_grapple_vertical.md)、current v2生成器、实际231px Traversal Resource、当前输入与调优。用户原话“空中使用射枪瞄准和钩锁瞄准的时间减慢，改成15％”“钩索命中拉过去是可以挂在那里停留的”“重点是空中连续操作成功的爽感”“森林这个区域我希望能够扩充更多纵向关卡”是本轮授权，不冒签乐趣。整体REVISE：冠叉R可省、尾路跳上层、上层收益/随机探索/QueenH仍未过。

当前JSON每个authority_sources都读取真实文件SHA；不引用会随本次记录变化的current_state/handoff来制造循环。每份JSON另保留historical_direction原路径/SHA。

## 完整旧bytes与证据边界

| 旧总谱 | 原SHA256 | 归档 |
| --- | --- | --- |
| windchime_plains creative-v2 | `8f07e1c3d8fdd3553f7bf373075a52b2b900aac703b4789cead2cc5ebeeb0fa4` | [原JSON](archive/creative-v2/windchime_plains.json) |
| thorn_forest creative-v2 | `c79445e94ed41217ec326b0a928f1b6e723a754d66a8cc3eabcfd08e6c01b150` | [原JSON](archive/creative-v2/thorn_forest.json) |

归档来自本次修改前原始bytes，不重排、不改旧hash。嵌套archive不进入当前目录glob；显式用当前load_direction读取旧v2仍必须因Authority changed拒绝。旧历史实机/电影、冻结mission、审查与质量记录全部保留原version/source，不替换里面的direction binding。新的v3绑定只允许启动新任务；旧绑定不成为v3通过。尚需当前整合冻结源完整docs/core/art/Web、实际GUI与独立审查；技术通过仍不等于玩家/设备或商业完成。

规划器仍保守返回formal_opening_authorized=false是现有工具授权边界，不是声称实际森林不可玩；本次没有将JSON当作运行时能力授予开关。显式prototype路径继续验证其真正技术样板，不能覆盖正式区域。

## 实际专项验证

[原CLI回执](validation/creative-v3/receipt.json)及同目录原日志：当前目录2总谱严格通过、creative原9+新增1=10 tests通过、routing原24 tests通过。原Authority changed/区域混用/缺主题/单候选/重复候选/丢比较/未选择负例全部保留；新增两份历史原JSON精确SHA和creative-v2身份，并显式证明旧总谱不能用当前权威装载。`git diff --check`通过。此处只证明创作输入/绑定/路由，不是原生动作、美术、Boss或完整docs回归；完整docs由整合主任务冻结后执行。

## 发现的通用美术规划器用途阻塞（未修工具）

实际只读调用`level_design.route_request('优化风铃平原美术')`已绑定v3，却仍进入`visual_director.py`的regional分支：`p1_regional_assets.json`、`plains_regional_composer.gd`、旧`docs/evidence/plains_regional/recipe.md`，recipe明确candidate_not_automatic_admission / blocked_art_RETHINK_not_mature_production。该plan不能作为PR91当前默认像素生产，v3校验通过不等于通用美术流程已经迁移。不能把P1偏好或旧画面审查签给quiet pixel。此限制同时写进active Plains JSON的planner_boundary。

[实际plan观察](validation/creative-v3/planner_scope_observation.json)仅是计划输出，没有执行worker/捕获/改资产；包含通用请求、缺“地形”时仍不匹配源画分支的请求，以及完整显式源画地形请求。最初裸请求“从源画重建风铃平原美术”还因缺优化/制作工作流词实际Ambiguous workflow拒绝，不能称已执行候选。`world_rebuild_request`需要源画+重建+地形/地貌+美术等词才选择显式PR90候选。

本次不扩工具范围：允许整合部署现有runtime，**暂停这类generic美术生产用途**。后续应在原有route里按实际current direction选择像素消费者与原验证，把源画/P1保留显式候选并补自动继承负例；不新建捕获或质量体系。此问题不改变当前运行默认是PR91，也不重签旧技术/美术证据。
