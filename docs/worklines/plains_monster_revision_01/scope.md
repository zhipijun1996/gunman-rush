# 平原怪物返工 · PLAINS-MONSTER-REVISION-01

状态：in_progress／待逐怪复审。基线 `0d33ab56cb06d5bb37b30bd82387415ae5c7725e`；分支 `feature/plains-monster-revision-01`。本轮用户明确给出七只怪的体型、材料、动作、受伤、死亡与退场修改，并追加“像素粒度要对齐整体美术”。这构成制作依据，不是对新成品的验收通过。

## 实施范围

- 普通怪不再绘制血条、血量点或血量数字；去掉纯辅助瞄准线、路径线、状态标记和括号尺。Boss 只去纯辅助线，保留真实攻击、弹体、危险实体与玩法状态。
- 平原巡逻、冲锋、跳跃、草籽哨兵、扇射哨兵、根铃采用同一生成母版内的六个新中性身体，再以各自身体关节驱动整套动作。俯冲保留原身体图、尺寸和蓝灰／旧铜配色，仅精修动作衔接及落地收尾。
- 所有新动作消费真实 AI 相位、Motor 位移、已接受受伤／致死事件及暂停时钟；不由动画结算攻击或搬动 Actor。主身体碰撞与画面对应按本轮授权核对，不能以保留旧碰撞为由忽略尺寸差异。
- 正式平原包含玩家、俯冲和修改怪物的同屏比例比较；完整链录到死亡落位及稳定留尸／停留淡出。新版本另立，工坊旧视频与旧拒绝保留。

本轮沿用 [enemy-creator](../../../.agents/skills/enemy-creator/SKILL.md)、[animation-vfx](../../../.agents/skills/animation-vfx/SKILL.md)、[art-director](../../../.agents/skills/art-director/SKILL.md)与[统一完成标准](../../quality/enemy_completion_standard.md)，使用原 G0–G5／十一维，不新增审批门、不修改技能验收政策。逐项制作与待验见 [spec](spec.md)，状态以[本轮质量记录](../../quality/records/PLAINS-MONSTER-REVISION-01.json)及实际证据为准。

## 来源与边界

风铃平原 Bible 仍为 [v2 原文](../../creative_direction/bibles/1-windchime_plains_region_bible_v2.md)，共享方向继承 [style-v19](../../creative_direction/bibles/style-continuity-20261029-v19-program-refactor.json)的细像素、1wu 采样与 nearest。新素材与动作需要按真实消费者重验，不能继承旧 source 的视觉通过。

两次成功 `image_gen.imagegen` 输出及首次参数 schema 拒绝均保留：[逐字请求](../../../assets/plains_revision_01/source/prompts.json)、[来源与裁区](../../../assets/plains_revision_01/provenance.json)、[原始母版及派生清单](../../../assets/plains_revision_01/manifest.json)。首版调色图为历史候选，当前六体取自第二版 master；没有生成俯冲替代图。工具未暴露模型与许可信息，均记 unknown，不推断授权。

当前只记录制作内容及验收目标。引擎运行、正常速度实景、碰撞吻合、辅助线清除、声音、生命周期、独审和用户／设备认可分别取证；缺证据保持 unverified。死亡动作、稳定终态及 G5 未验不能因代码存在或 PNG 有哈希而签整怪完成。游戏主线不自动合并。

## 实际实施的主身体边界

根铃的主身体碰撞由36×40调整为40×48，Definition v1→v2，以包含放大后的铃体；生成与比较样本继续按真实Definition脚底装配。其余怪物先保原主要身体碰撞，角、长喷口、叶／翼外缘不作为整块实体。具体同屏与命中仍须实测，不能由此段签吻合。草籽哨兵Definition v3增加权威喷口pivot/reach，真实籽弹从原中心至喷口先做原半径扫掠，保墙优先／近身Policy命中；其他怪默认零偏移。该用户要求的身体/喷口调整不改变HP、伤害和原相位时长。

正式同屏复审发现原扇射碰撞28×32超过核心腹，现v3改为22×18：包含约14wu腹体及其约3.3wu镜向中心偏移，翼面不作为整块实体；冲锋v3由28×32改28×28，去掉旧框高出新壳顶的部分。保Actor中心与原朝向/存档/枪口语义，不额外添加偏移权威；具体动态擦边仍按实际物理和画面复审。

碰撞适配另修冲锋require_floor支持探针：使用实际RectangleShape2D的脚底与leading halfwidth+1，射线从sole-2至sole+8（原10wu长度），避免旧硬编码在exact贴地时从地板边界开始漏检。旧339/2失败与修后340/0保留；其他require_floor=false调用及_hit_landing_supported未改，不能声称旧射线位置完全等价。

完整回归另发现forest_vertical_expedition._ecology复用charger时写死旧16wu半高。仅该条spawn.y改为读取真实Definition.collision_size.y/2，保原脚底/横向边界assert、支持面、其他行、地形与RNG；新28高实际y比旧值低2wu，v14/v15 App均37项局部通过。平原录片源7edda9不受此森林技术适配影响，不给旧片改源标。
