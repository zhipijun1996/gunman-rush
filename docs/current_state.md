
# 已部署：风铃平原正式两图像素重制候选

试玩：https://zhipijun1996.github.io/gunman-rush/?plains=1&v=d2c684ef8fc0
Web build `d2c684ef8fc0`；运行源 `c0f8e50770145795db5affd4afdbffff2479f1ea`；PR91仍draft、未合main。[交付身份](evidence/windchime_pixel_01/delivery.json)与[独立审查](evidence/windchime_pixel_01/formal_review/report.md)。后续证据/交接提交不改变该运行源。

最新用户认可小样感觉后授权整个平原、3张独立大图视差、纹理简洁，并允许dual-grid。两张正式地图的地形、主角、敌人、两Boss、机关、拾取与装饰已接新像素表现。正式非整格平台使用精确并集边界适配，**不是已实现dual-grid/47正式TileMap**；47小样独立保留，新网格模块可选dual-grid，其他15区不复制同色遗迹。

已修脚本退出依赖环、破桥后悬空装饰、受伤反馈与竖屏天空覆盖。基础5676/0；区域15套分批完成（原失败保留，旧双背景断言保留为legacyfixture，新三层默认另验）。最终冻结源又复跑地形2097/0、小样19/0、生命周期27/0、背景/Boss兼容488/0和实际正式消费者21000/0，严格退出干净。独立最终普通入口/两图敌人和Boss前段0脚本/着色器错误，GPU每图552960/0；发布后HTTPS实际走跳/版本核对也0错误。

任务 `WINDCHIME-PIXEL-01` 保持review：完整全区审美/所有敌人警示与Boss阶段、完整听音、实体设备/性能和最差Seed未签；不能用定位fixture冒充自然通关。适用docs/art/gameplay/web全量harness在稀疏历史证据断链处阻塞；继承asset-consumer审计`assets/production_repair/`路径问题仍在，未降标准。下一步按用户实际试玩反馈精修，未来新模块先验证dual-grid对角/孔洞/薄台/返程净空；不自动开放后续地区。

关键命令：`python3 tools/run_pixel_plains_tests.py`、`python3 tools/run_pixel_formal_tests.py`、`python3 tools/harness.py --profile docs --profile art --profile gameplay --profile web --jobs 1`（完整历史证据未取齐时仍失败）。所有来源/失败/限定证据见[本轮目录](evidence/windchime_pixel_01/README.md)。

以下为历史，不覆盖本节。

---

# 当前：正式风铃平原像素重制候选，准备冻结与交付

用户已认可新小样的感觉，授权整个风铃平原、3张独立视差远景，并要求纹理简洁、允许dual-grid。任务 `WINDCHIME-PIXEL-01` 覆盖旧“一屏不扩区”边界；不重开预算、旧暖色失败不追认。

两张真实PlainsRegionStage与普通标题主按钮已迁移新地形/主角/敌人/两Boss/机关/拾取/箱子商人和独立小物，3张新PNG分别随实际相机移动。现有非整格碰撞由精确矩形并集表现适配，**不是已实现dual-grid正式地图**；新网格模块可选dual-grid，47小样保留。见[本轮证据](evidence/windchime_pixel_01/README.md)。

已取得core5676/0、专项2097/0、独立几何32231/0、两图普通消费者21000/0、真实教程574帧/独立视差16/0，GPU两图各552960/0。定位艺术工具自然死亡后的Nil错误已加有效性守卫并在build4独立GUI0脚本/着色器错误复验。新helper脚本依赖环引起退出资源泄漏，已保留原失败、300d65c对照和修复后的原2871/0严格干净退出，正在完整15套回归。

当前draft Web d54a2ddedf5f是300d65c+dirty，尚未上线；最终将从冻结提交重新导出、复验并替换HTTPS，不能给旧45c1a10f8767冒充新版。适用harness因稀疏历史docs断链先失败；并行clone还受promisor历史对象缺失影响，未降标准。最终整区用户审美、实体设备/完整听音和全部最差种子仍未签。分支feature/blob47-art-foundation，PR91保持draft且不合main。

以下为历史，不覆盖本节。

---

# 最新用户反馈：暖色平原候选被拒，停止扩产

用户认为“本来是有特色的美术，突然又变得廉价了”，并提出参考《动物井》。本轮暖灰绿石体、规则砌石与通用草甸组合未通过用户视觉验收，停止作为母版扩产和发布。已有47态/碰撞、实际Motor与生命周期技术结果保留，不签美术。Animal Well的像素材质、自然轮廓、光照和环境生态是下一步讨论/小样方向，不能自动将16区全部改成暗色地穴，也未据此完成新素材或新画风。下面暖色候选与16区配色仅供失败溯源，不能覆盖本节用户判断。

---

# 最新：风铃平原暖石灰岩手工样板与16区视觉分工

任务 `WINDCHIME-STYLE-01`。用户对简化画法给出“差不多这样”的有限正向反馈，要求增加肌理，并指出深蓝配色不适合平原、需考虑16区。已按[视觉分工表](region_visual_identity.md)将平原改为暖石灰岩/鼠尾草/麦金、草甸风车和低钟塔；原天空钟城首稿只保留证据，不再运行。新47态×3、8件小物、跨格砌石/轻颗粒、独立视差和真实演员已接入 `WindchimeLab`，提供MAP00材料场与MAP01手工石拱庭。

实际主路往返、上层支路与木桥下穿1800/0；集成120/0；独审发现并修复死亡Restart的失效scope、旧弹体绘制、中文缺字与HUD对比。新图最终用户认可、实体设备、完整听音与正式两图随机迁移未验；MAP02/模块随机按原阶段在首样板后推进。最终冻结源与Web交付正在收口，不能用旧build当新版。[本轮证据](evidence/windchime_style_01/README.md)。

以下为历史，不覆盖本节最新方向与实现范围。

---

# 最新：参考瓦片视频的后续map规划已交付，生产尚未执行

任务 `TILE-MAP-PLAN-01`。已读取用户给定B站视频的关键画面与烧录字幕，按[后续Tile Map制作规划](tile_map_production_plan.md)组织同族素材→手工样板→模块库→受约束随机。首期一套草土石，先代表块与接口，再完整47态；MAP-00材料验收场、MAP-01横向草坡石拱、MAP-02回廊井庭逐步验证，之后才拆6–8个模块和抽样Seed。

[视频来源与观察](evidence/tile_map_plan_01/observations.md)注明43个抽样时刻及字幕方式；没有声称完整听读/逐字转录。尺寸、模块数量、地图拓扑与Seed规模是项目候选，不是视频结论。卡通画风要求和V1拒绝状态保留；本轮没有新素材、实机地图、生成器改动或Web发布。

以下为历史记录，不覆盖本节规划边界。

---

# 最新画风反馈：V1已被用户拒绝，转向洞窟探险2/马里奥制造2的饱满卡通

2026-10-19，用户认为已交付截图画风“太丑”，明确要求靠近《洞窟探险2》或《马里奥制造2》。V1 SVG色块方案停止扩产；47-tile、碰撞/模块语义等技术地基继续有效。新[风格规范](art_foundation_v1.md)落实厚实圆润地形、饱满草帽、清晰体积/轮廓、鲜明配色与协调道具，[方向B概念](evidence/blob47_cartoon_02/concept.png)为本轮从零图生原件；[来源与边界](evidence/blob47_cartoon_02/README.md)完整保留。

新图仅是游戏比例概念，未切成47格图集、未接入Godot、未获用户认可。当前Web build `45c1a10f8767`仍显示被拒绝的V1；不能冒称新图已上线。原V1质量记录的visual/G2已按本次反馈改为failed；原技术通过不被抹掉。任务 `ART-BLOB47-CARTOON-02` 为review；下一步依据画风反馈制作接口母版与实际合屏，不继续微调旧SVG配色。

以下为历史记录，不覆盖本节最新用户视觉判断。

---

# 新美术地基：47-tile候选，正式迁移与最终画风未签

2026-10-19最新用户要求：完全抛弃过去美术方向，以[新地基规范](art_foundation_v1.md)覆盖所有历史风格/母版/地形制作要求；取消空洞/奥日目标。新增 `Blob47Lab` 独立标题入口，47状态图集、三层背景/玩家/装饰、严格模块卡与可复现拼接。保留正式玩法运行兼容，不以旧资产作新创意输入。

核心专项20356/0 + 958/0，独审另验10种子低层双向20路线；完整合屏黄金、可选上路、用户画风/实体设备与正式地图迁移未验。当前完整profiles因本地稀疏检出未物化历史证据停止，不删检查或冒称全绿。[独审](quality/blob47_independent_review.md)仅接受限定地基技术范围。已导出并部署[新地基独立试玩](https://zhipijun1996.github.io/gunman-rush/?foundation=1&v=45c1a10f8767)，build `45c1a10f8767`，游戏源码 `222ee12fa002710de104d31f660ee275c1e6d2f6`；部署运行 [39201666634](https://github.com/zhipijun1996/gunman-rush/actions/runs/39201666634) 成功。浏览器真实7项通过，最终7图已不同作者实看；[精选证据](evidence/blob47_foundation/README.md)。[草稿PR91](https://github.com/zhipijun1996/gunman-rush/pull/91)不合并main；后续证据提交不冒称重新导出。 任务review。

以下为历史记录，不覆盖本节新美术要求。
