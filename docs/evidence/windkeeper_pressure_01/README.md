# WINDKEEPER-PRESSURE-01：60HP牧风者审核候选

正式map2已接入主动追近、六种全身动作、三阶段加权冻结招组、真实平台支撑与跨台、共同姿态驱动判定、致死止伤止风、1.9秒失效和20金币物理领取。运行源 `7f919a225e703c6a9cbb8091ab0e956595b8b859`；后续140运行引用逐件字节相同，改动限正常输入录制、原消费者适配和证据。分支 `feature/windkeeper-pressure-01`，[PR124](https://github.com/zhipijun1996/gunman-rush/pull/124) 保持草稿，不自动合main。[当前制作卡](../../worklines/windkeeper_pressure_01/spec.md) · [原制作卡](spec-original-01.md) · [质量记录](../../quality/records/WINDKEEPER-PRESSURE-01.json)。

## 当前可审影片

- [完整主片：88.867秒，原声，1280×720/60fps](media/windkeeper-60hp-complete.mp4)：不剪接。实际60次有效命中、17组起手/16组完成、玩家3HP存活，三阶段六招、死亡与20金币全部完成。[实际来源及统计](main-movie-summary.json) · [原始完整轨迹/引擎日志/源守门ZIP](main-movie-original-evidence.zip)。录制源 `b684b76e71143df6fdbcdf70307cc2b4e8f124d7`，MP4 SHA256 `e8b89682f632e7ddad4ab47ca9394bae3494830baa3f14f280642caeadde96dc`。
- [第三枪对照：68.433秒，真实失败保留](media/windkeeper-60hp-third-shot-failed.mp4)：与主片同运行源/seed，正常输入策略的最终恢复上限从2枪改3枪。玩家在48次有效命中、14组后死亡，Boss剩12HP，没有死亡或奖励结算。[实际失败报告](greedy-movie-summary.json) · [原始失败证据ZIP](greedy-original-evidence.zip)。录制源 `46e00839154ab648bb0b6024f98fbcfb00dbe08a`，MP4 SHA256 `8d947272e0e9e49dea1f5e95a48ef5b4908229244375b1a1bfc15c879ee50784`。wrapper原8项错误保留，不能称完整战斗通过，也不能把之后的死亡直接归因于第三枪。

[第三枪实际章节](greedy-gpu-review-chapters.json)与[独立实片/逐枪/原消费者审查](third-shot-independent-review.md)另附：组4的14.533–18.05秒三枪全中且最后一发处收招余量约0，仍成功脱离；组8的28.617–35.60秒第三枪后仍余0.5秒；组9的34.417–38.70秒呈现余量与随后接触受伤。两片在第一组第二枪后就因争取追加改变走位，后续死亡不是严格逐帧单变量A/B。

两片均使用真实 `DemoApp.start_debug_region` 的正式平原地图2，明示调试入口和一次开战前站位；之后只走正常Router/鼠标。玩家基础5HP、基础武器每次有效伤害1，无中途改HP、资源、RNG、Boss状态/时钟/相机或位置。它们是完整连续遭遇实录，不是从标题开始的自然整关通关。主片 `active_assault` 含合法攻击准备期额外射击，不是仅在恢复期打两枪的稳健打法证明。Godot原MovieMaker stereo48000 PCM转AAC，没有另配声音；音轨存在不代签听感。

[实际GPU审核章节](main-gpu-review-chapters.json) 直接来自主片逐帧记录，不使用headless候选时间代替。两枪逐弹体ID与Boss实际扣血相连：15组发出两枪，9组两枪都命中，8组第二枪至下一次出手前无伤；group9随后39.333秒接触受伤，不能列为安全撤离。阶段变化带来的延窗和此前受伤分别标注，尚未证明所有朝向/站位通用稳定。

| 审核重点 | 主片时间（秒） |
| --- | --- |
| 重踏钟波／仰首风籽 | 3.50–4.39／4.65–5.49 |
| 低身短扑起落 | 7.42–8.95 |
| 原地停留时主动逼近 | 11.183–11.833、15.167–15.800 |
| 展帆风压／风叶横扫 | 30.25–31.32／33.18–34.35 |
| 第三阶段与踏台 | 55.45起／58.70–59.87 |
| 三招推进及最终恢复 | 65.817–70.700 |
| 两枪都命中并撤离（组6／组15） | 20.717–26.14／70.717–78.59 |
| 致死／撞击喷币／残骸／全部拾取 | 84.85／85.90／86.767／87.983 |

原始章节里7.233–9.217秒曾被producer标作原地观察，但实际玩家位移约460像素，独审已标记不可用；不能用这段签站桩追压。当前采用后面两段实际零位移观察。当前场景封场/状态文字仍可能和上层结构重叠，合屏和整段动作仍待审，不以轨迹计数代签艺术质量。

[怪物工坊](https://gunman-monster-workshop.zhipijun1996.chatgpt.site) **第8版已实际私密发布成功**，选择“牧风者（60HP · 三阶段追压）”。[发布收据](workshop-publication.json)绑定Site源38b74376，原owner-private受众/权限revision1不变；[两条原MP4完整HTTP200下载](raw-media-http-01.json)逐字节SHA匹配，[线上播放器Range206](site-http-01.json)的2048字节实际载荷也与原片相同，海报HTTP200。API13＋UI19原测试、构建及ESM/纯schema迁移检查通过，[原日志](workshop-tests.log)保留；本轮未实际操作浏览器GUI。旧36HP版本/ID/修订/动作和原意见、经典12HP牧风者、巡游机与其他24只目录记录保留，没有数据库意见/创意写入。

## 实际技术与原消费者

- [六消费者原生报告](native-six/report.json)：97几何、1198组件、63正式App、72支撑、77奖励、130声音事件，共1637项0失败。运行源ff517243，140运行字节与当前逐件相同；原始日志/来源不改写成后来提交重跑。受控场景与连续片互补。
- [原R3完整wrapper第二轮](original-consumers/original-r3-full-02.log)及[原始输出ZIP](original-consumers/r3-full-02-original-evidence.zip)：干净46e源实跑，100组件/16方向/54生命周期0失败；map1 459帧、map2 5053帧0失败，牧风者60HP实际击败且玩家3HP，原Gold、物理20金币、钩索选择和进入森林均完成。原14失败断言、7200帧120秒战斗、180秒子进程与360秒Harness预算不改。初始房间站位和胜利后金币靠近fixture仍明示，不能称这份测试是自然实片。
- original-consumers/ 保留共享core5686/0、enemy-structure733/0、boss-time1182/0。原boss-time变帧率失败、原测试不改的固定60Hz诊断及实际wrapper复跑原日志俱在；只复用既有fixed-fps适配，原断言/120秒子进程/240秒Harness保留。
- [四项绑定Harness](binding-four/report.json) fresh通过；原dirty main840108da来源保留，未重签后来clean源。[独审](independent-review.md)、[原检查迁移](guard-migration-review.json)、[当前交付审计](final-delivery-audit.md)只接受各自实际范围。当前style24/creative27的140引用、原83有序前缀、原40/17方法与四预算保持；原full168有序前缀只追加专项为169（92并行/77串行）。[22项选择器原测试](production-plan-tests-02.log)通过不等于169项运行。
- 原cc0074b1 CI并行失败为Task index/record mismatch；46e已补规范任务表，本地记录/任务守门通过。新精确head完整169CI仍须核实际状态，不把prepare或本地专项当完整CI绿灯。

## 失败、诊断与待验

failed-battles/ 保留01–11、active01/02、platform01/02、assault01/02/03等原连续失败，以及原R3 map2余21HP/玩家死亡失败。headless-greedy中断包保留驱动死亡轨迹；外层会话在环境重连时中断，缺最终wrapper报告，未补造source稳定PASS。另录GPU第三枪片有其独立真实源守门及失败终态。所有失败不被后轮胜利抹除。

[dodge-probe/](dodge-probe/) 共有32个明确受控起手试验、512项setup检查0失败；13条所测输入路线安全、19条不安全。每例起手前可设阶段/招式/站位，之后只走正常输入；只证明所测退路，不能升级为自然整战公平。原竖跳/错误越身、风籽迎面跳与落台后未释放jump的失败均保留。[支撑返工](../../worklines/windkeeper_pressure_01/support-repair.md)另列当前v6验证和已获用户延期的旧v5兼容。

[pose02技术收据](pose02/source-report.json)为两尺寸60张静音暂停样板；原ART09拒绝和限定材质返工接受分别保留。actual-film-review/ 是从本轮真实主片抽取的时间样帧：短扑可见压低→真实升空→前肢落地承重；8fps样帧不能代签正常速度整体动作。原BGM、受伤A、玩家物理、现有身体PNG、1wu/nearest规格未替换。

质量仍为候选、非done。正常速度的整体动作/合屏、预警与命中混音听感、持续风向/草叶响应、所有站位的稳健两枪、第三枪真实操作余量、完整169CI、实体手机性能及用户认可分别保留未验。
