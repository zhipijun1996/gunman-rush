# 森林与候选怪物资料/素材现状审计

只读源版本 `310c0421e18829088a4d2208c5f1b6cba3db35dc`。已核HEAD完整路径树并以git show补查sparse缺文件；未改仓库、未启动引擎。这里只记录资料和使用事实，**不判断我先前实现的美术合格，也不把程序形变本身判为好或差**。用户对上一轮整体质量的拒绝没有被旧记录覆盖。

| 对象 | 当前PNG | 当前动作消费方式 | 其它动作素材现状 |
|---|---|---|---|
| forest_lantern | fine_32/lantern.png | 单张PNG + 16×16网格 | 查到静态旧母版；未查到该物种专用动作/受伤/死亡序列 |
| forest_seed_sentry | fine_32/seed_sentry.png | 单张PNG + 16×16网格 | 查到静态旧母版；未查到该物种专用动作/受伤/死亡序列 |
| forest_bark_beetle | fine_32/beetle.png | 单张PNG + 16×16网格 | 查到静态旧母版；未查到该物种专用动作/受伤/死亡序列 |
| forest_swing_pod | fine_32/swing_pod.png | 单张PNG + 16×16网格 | 查到静态旧母版；未查到该物种专用动作/受伤/死亡序列 |
| forest_crossbranch | fine_32/crossbranch.png | 单张PNG + 16×16网格 | 查到静态旧母版；未查到该物种专用动作/受伤/死亡序列 |
| forest_thread_spider | weaver_silk_bell_v5.png | 单张PNG + 16×16网格 | 查到静态旧母版；未查到该物种专用动作/受伤/死亡序列 |
| forest_bible_weaver | weaver_silk_bell_v5.png | 单张PNG + 16×16网格 | 查到静态旧母版；未查到该物种专用动作/受伤/死亡序列 |
| candidate_lure_guard | prototype_sheet.png | neutral裁区 + 6×8网格 | 有意图为动作/受伤/死亡的旧与新sheet，但未按动作消费 |
| candidate_crosswind_moth | prototype_sheet.png | neutral裁区 + 6×8网格 | 有意图为动作/受伤/死亡的旧与新sheet，但未按动作消费 |

设计资料主要分散在 `docs/design/forest_enemy_ecology_v2.md`（萤/哨/旧蛛/跨枝）、`docs/design/forest_feedback_ecology.md`（甲虫/吊荚）、区域Bible第7节（外形与生态）；`forest_bible_weaver` 的双入口差异在专有Behavior和地域设计里。`docs/worklines/enemy_all_02/forest-production-cards.md` 是后加实现卡。未在本次完整跟踪文档搜索中定位9个独立完整的逐怪Enemy Design Sheet。两候选的玩法/参数主要在 ModuleEnemyPrototypes 和 ActionStudio 代码，形象动作意图在 asset_generation_notes，仍是开发入口。

森林普通身体实际由四个Presentation → `ForestBibleActors` → `ForestMotion02`消费：只有祖先Bible-art metadata及身份条件成立才读这些PNG；否则仍画备用几何。五种使用fine_32重制版，两个蛛共用同一weaver v5。fine_32/ecology_build和boss_beetle_build是裁切/缩放构建记录，不是动作序列manifest。旧native v1、weaver v4和两份8实体概念atlas仍在库；8个不同实体不能计为8帧动作。

两候选有**现成但当前没用作动作的素材**：旧 `assets/plains_v7/enemies/guard_moth.png`（6列×2行）及新 `assets/enemy_all_02/prototype_sheet.png` 的其它姿态包含意图为受伤/死亡等状态的图。当前manifest只选择guard/moth各一个neutral裁区，后续所有状态都由同一裁区网格变形，死亡沿原.6秒淡出；第二轮sheet作为拒绝原件保留。这和“没有任何动作图”不同。

9种均没有消费charger/diver的专用H/D序列：EnemyFeedback01.PROFILES只登记平原冲锋/俯冲。它们共享accepted-hit状态、闪色/形变、程序接触扇和碎屑；专有部分是预警线/落点/盾闪/摆荚绳/蛛线及各自代码关节。死亡素材也是原身体，三森林类短暂收束后隐藏，四类保暗色身体；这不是专门绘制的死亡序列或持久尸体系统。

声音需分层看：EnemyActor的enemy_hurt/enemy_defeat、telegraph的warning、哨的enemy_shot/bell、候选盾的armour均走共享cue；蛛的extend由Stage触发区域共享forest_web.wav。甲虫shield_contact当前可定位到视觉闪线订阅，没找到直接对应专有声音订阅。未发现这9种各自独立的受伤/死亡声音银行，未做听感评价。

需保留未知：族manifest仍有native v1 direct_sampling=true等历史字段，与真实helper已选fine_32并不一致；状态字段不等于当前消费或用户认可。weaver v1–v3只在v4 provenance里有早稿描述，本次没有把其引用当作可用动作资源。完整逐物种路径、SHA、来源/历史/当前状态、行号证据和限定缺失见 `forest-inventory.json`。
