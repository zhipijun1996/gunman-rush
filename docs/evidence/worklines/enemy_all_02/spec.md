# 全怪物同体动作制作与实机审核

task_id: ENEMY-ALL-02
baseline_commit: 20e67867b272a7e461eddce169a0cdb83353f4b6
content_version: enemy-all-02-candidate-v1

用户要求：根据已建立的完成标准和开发流程完善所有现有怪物，并交付实机视频审核。玩家体验是身体身份始终一致，能读懂移动、蓄势、攻击、受伤中断、恢复及原死亡终态。

## 现有范围与方法

以 roster.json 的真实消费者为准：14种常规怪物、22条身体渲染链、2个开发候选，8个Boss场景（牧风者另含正式storm与旧scene Definition组合）。孤立资源不计成已上线物种。普通与Boss分别保留原正式／开发／历史准入。

按原开发手册先审计实际母版、消费链与失败，再补真实状态驱动的同体关节。冲锋／俯冲live统一为H3母版，原H0–3/D4–7八帧及accepted HP反馈保持；腿、翼、炮颈、根枝分别关节化。森林按物种肢体变形，Boss胸心、预警、HP独立。候选透明母版经两轮真实imagegen，拒绝比例漂移的姿态，仅采用两个中性母版作同体动作，不宣称生成12帧动画。

所有表现只读Actor/Encounter状态、位移及已接受事件；不得写AI、HP、碰撞、弹体、奖励、阶段、存档。各怪按原终态政策：冲锋／俯冲留尸并保存，其他保留原隐藏／暗色／Boss终态，不能强制所有怪留尸。暂停、epoch重建、卸载释放继续适用。

## 地区与源绑定

沿当前registry/style-v18/creative-v21及81条引用原件，不机械重绑历史证据。本轮局部消费者源清单另冻结，实际运行用完整Git source guard。

- windchime_plains_v2 / 2.0：docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md，SHA256 02c9dd3299d12c91a426cf40b2a5885e526b51f467b955539b4b5ff99e1aca35。
- thorn_forest_v2 / 2.0：docs/creative_direction/bibles/2-thorn_forest_region_bible_v2.md，SHA256 a7bad8323af64a7be0577132e5d988a6e1b781d9e1ac1639d37f9d65935194e3。
- 用户已选地区方向；使用现有BGM／声音，不生成替换音乐。原32px地形、1wu最近采样与原预算不改。

## 交付物与失败判据

逐物种制作卡、源码／素材／许可记录、完整库存、正常速度带原音轨实机MP4与逐帧输入／AI／HP事件追踪。初始测试台明确披露，不签自然campaign；另录正式场景合屏。视频必须观察真实攻击、非致死伤后恢复、死亡与210帧终态；缺口逐例标出并返工，不能用节点存在签视觉通过。

失败包括身体重影或换形、脚／荚柄漂移、网格撕裂、受伤退出跳变、预警跟身体扭曲、非accepted事件闪白、死亡循环继续、场景退出残留，或素材消费无有限清单。原反馈／留尸／保存／森林／Boss检查和预算保持，失败日志保留。技术命令通过只签其边界；独审、真机和玩家最终审核分列，候选状态不签done。

证据：docs/evidence/enemy_all_02/；最初解析失败保存在build/enemy_all_02/lantern-first与lantern-second，不覆盖。未验项目包括最终玩家接受、物理设备帧时及未录到的动作反例。
