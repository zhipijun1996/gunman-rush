## main 合并与原验证批次刷新

PR92已普通合入main fe704f9717dc1109605a5186b2acd94ba5b58792；导出真实拒绝stale Foundry。原命令保留24/6/6、36短句18连续路线、三个原300秒cap和原validator，真实全部零失败并生成原stamp；重新冻结后的main才是试玩源。刷新仅开发练习场产物，不改正式能力/物理/池。actors JSON来源文本修正为常量声明路径，当前PNG preload而非JSON运行读取。当前导出/公网仍待完成，不签质量通过。

# PARALLEL-INTEGRATION-01：并行分支整合与重新部署

## 最新用户授权：合入 main，快速交付有明确未通过项的试玩

新增 PR94 `feature/underworld-plains-production`／`0fab13fcc446bf9abd3c6beaf21e0fc5b76bd9ad`（15:54UTC远端复核仍为该head）。它基于PR93，更新正式平原、人物、机关、Home和共享UI，不是仅Lab。现合成保森林v12、15%、231射程、碰撞、RNG/保存，保正式与候选分离、当前触屏适配、Latin/CJK fallback和真实同一player跨区重建。新增真实Campaign H账本前置修复仅测试fixture，逆向回程明确不是自然战役。

用户现在明确授权合main并快速试玩。采用既有prepared Pages试玩传输，原完整CI110、600秒、每case240秒、原GD与所有断言不放宽；预览不冒称完整release。main提交/线上source/PCK须后续独立核实。原普通merge在本地浅克隆stash读取历史对象失败，源未改；以独审过的75份解决稿构建精确tree并用干净索引受保护two-tree checkout应用，最后保64/PR94双父普通merge拓扑，不强推、不覆盖用户改动。

CI8 `39268123826/1` 实际FAIL：serial22PASS；parallel50PASS+forest-depth-region600.045秒TIMEOUT+25未执行。完整80中70真实PASS，耗时590.620秒，加导入7.488秒几乎耗尽预算，后10未完成；不是workflow60分钟总上限。准确source64包本机73/23/20八场景PASS，但未部署且不转签PR94。现有runner改为仅corpus有界2worker，保原80/240/90/600、validator、父lease、独立进程/输出/用户目录和有序父收据；11实际小进程及独审通过，真80仍未证明。

当前dirty整合源：core5676严格PASS；原共享native脚本73/0与campaign fixture56/0干净；原menu43功能全过但严格退出49ObjectDB/37resourcesFAIL，音频／旧overlay／去menu注解／完整旧menu四次有界对照均未消除，根因UNKNOWN，没有屏蔽leak。原scenery冷checkout因缺输出父目录FAIL，只修CLI创建目录，原GD不动；同原150秒cap冷测41.967秒PASS，实际20图20802/0。pipeline audit869／原107测试55.485秒PASS（后仅CLI mkdir，audit与断言不变）。新Underworld其余检查/完整新CI/新Web仍待。

[选择性原始证据及限定审查](evidence/parallel_integration_01/main_preview09/README.md)。完整大包与旧失败原件仍保留本机会话Vault；不冒称全部原件永久可下载。森林设计REVISE、旧fan首次点击UNKNOWN、真人趣味／审美／实体设备均不改签。


## 第七候选实际失败与第八候选准备

第七候选运行源 `1fd766e9d76e84289a51e47b13633969d48d0eeb`，dispatch `39259805819/1`：Web/Windows导出成功，完整98项尚未通过；串行lane实际16项通过后，历史v1矩阵在restore阶段因缺旧 `assets/manifest.json` 原blob失败，尚未启动该矩阵断言。已从真实Git对象保留原blob `01393ff2484e4e9541c7f96f067e17688f63607f`，原restore/verify闭包通过，不改冻结夹具清单、原测试或时限。docs原24项通过，production-loop原107项42.563秒通过（原60秒预算）。

准确CI Web包build `05208e559de9` 的原浏览器72项协调器实际失败：首24项19通过、5失败，后两消费者未执行。四项二段刀断言由首个40ms点击没有产生accepted packet引起，根因尚未证实；原生GUI对照19/0仅证明有限原生输入路径；唯一被动浏览器诊断在原输入前缀8/8通过，观察到131–165ms长任务，但缺adapter/queue时间证据，根因仍UNKNOWN，不覆盖原浏览器失败。第五项是旧垂直钩拉45度断言与现行近垂直稳定合同冲突。同一CI包真实GUI侧环/竖环对照分别观察 `[-240,-240]` 与 `[0,-240]`，并恢复free。第八候选保留原45度表达式验证既有侧环，另新增读取真实Resource/default的近垂直检查，保留全部原72项、总数变为73，不改物理或输入时限。

同包独立Style Lab原23项通过；原地区GUI20/8在真实进入平原1/2后因全帧HUD OCR漏读失败，未完成任何完整case。采证修复保留原region定位，并始终要求完整地区+地图标题唯一匹配，使用实际HUD四个位置的整行像素预处理；错误地区/地图、EXTRA、空白、重复标题负例均拒绝。原20项、8contexts、480秒及菜单点击不变。新候选完整CI、准确原包73与公开20/8仍待实际执行，尚未重新部署；森林REVISE、真人和实体设备边界不变。

整合基线：森林 `ac002e7641fd282c291cdd7c25c9cf5d2450ce0a`。新分支 `integration/forest-plains-20261019`，保持未合 main。

| 输入 | 冻结 SHA | 整合范围 |
| --- | --- | --- |
| PR83 森林 | ac002e7641fd282c291cdd7c25c9cf5d2450ce0a | v12、15%双瞄准、斜下钩拉、挂环、历史存档及区域流程 |
| PR91 像素平原 | 2f25083da11da11604a3535a2feae20d119ac001 | 正式两图地形、演员、道具和三层视差；旧风格失败保留 |
| PR90 累积场所实验 | 913d77afa4019a0a2e6c84f270f3fe30ac2f00ba | 含前序PR81/82/84–89等祖先；显式候选入口，不替换正式池 |
| PR80 剧情 | 3e0ce1caf02ab8c400f85d85f9540405b977cee6 | 重复末日剧情、地区叙事及写作Skill；非完整剧情运行实现 |
| PR93 五风格实验 | 8382a41cb0ccf9a8e2e56075ade9edaceb4ff67a | 本轮期间新增；显式Style Lab与三地区表现比较，不替代正式地图 |

按实际 ancestry 收敛累积链，不逐个重复合并祖先PR，不关闭原PR、不强推。main 当前为共同基线 e8ee34446aa82b4e64f5cdc414a22f5b6e2a6ca7。

共享入口按实际装配的地区同步角色和背景，防止平原像素皮肤污染森林以及跨区复用玩家留下旧皮肤。原始基础物理、钩索231射程、碰撞体、能力、资源和15%瞄准未改。Foundry冲突保留森林现行来源；各测试保留已实际修复且严格清理的森林消费者，未降断言或预算。

一次冲突脚本误吞DemoApp主体，独立审计及时发现；在部署前从三方完整原件重建，核对三来源全部函数，并增加实际消费者验证。该错误提交留在整合历史，最终文件以修复后源码为准。一次过早Harness定向运行因源在冻结期间变化实际失败，不计PASS。

存储：仅删除210个可重建.godot缓存（90,795,592字节），以及逐字节SHA校验后将1499个重复文件换为硬链接（约4.87GB）；源码、失败原件、日志和电影内容保持。原始路径清单在本机build/integration-{cache-cleanup,exact-dedup}.json。两个旧本地ZIP链接原环境路径不可取得，改为明确标注历史路径，不造可下载链接。

验证与发布尚在进行；最终CI、公开source/build_id/PCK及实际GUI以本页后续原始记录为准。原区域设计仍REVISE：冠叉反冲可省、尾路可跳过末两句、上层收益、Boss钩索价值和随机探索差异未解决；本轮整合不冒充新关卡设计完成，用户趣味/审美和实体设备未验。

## 冻结前实际回归

原生基本5676/0、钩索手感/挂环/输入系列、保存122/0、正式像素地形2097/0、像素样板19/0、共享表现30/0与原战役UI56/0通过。战役原Boss/奖励定位仅是结算fixture，不当自然通关。三个历史20%消费者保留全部旧hash与原断言，另对真实15%默认整份Manifest严格重建比较；world125/0、art-language2507/0、joint-recoil250/0通过。world新增真实几何与未知调优hash变造负例另验。原world124/1和像素样板缺父目录的真实失败保留，不追认成功。

独立只读审查接受源码整合、有限资产适配、元数据保管与表现消费者的限定范围，未观察实际画面/听音或签手感。72份新增资产carrier记录逐项保留实际来源，license unknown、visual unverified，不把Git来源等同商业许可或艺术准入。完整CI与新公开包仍待；原失败、专项日志与独审见[证据目录](evidence/parallel_integration_01/review01.md)。

三族消费者原CLI复验全通过；world随后新增两项重新派生hash的变造负例（地形位置+未知调优）也被严格拒绝，最终127/0。质量记录criteria格式错误曾被静态校验拒绝，随后修正记录格式，未修改校验器或豁免记录。

首候选2cb的push docs CI39229170834实际FAIL：107测试中4项缺ffmpeg（52.576秒），准确artifact12176782322/SHA绑定原ZIP保留；本地原107项45.396秒PASS。完整dispatch39229199208在已知CI缺依赖后终态cancelled（prepare成功，后续四任务取消、汇总缺lane失败，部署跳过），不能标完整通过或发布。修复只给docs/core/web安装ffmpeg/ffprobe，原测试与60秒预算不变；新源另跑正式CI。

## 第二候选实际超时与词法优化

第二候选d7f74556的push docs39230300225实际60.040秒超时；准确artifact12175224986/SHA93e8070ae230dce6c4fa0c715899881650e97ce8297f48c21aeb9f24e2640eb5原ZIP保留，不能把未完成107项计作通过。完整dispatch39230314758终态cancelled，未部署。原件见`evidence/parallel_integration_01/ci02/`。

一次完整只读profile定位112次真实输入预检中的重复纯词法路径计算；只优化POSIX component前缀与相对名称切片，Windows保留原pathlib规则，不缓存文件系统或预检结果。107个原测试和60秒上限保持，原symlink案例补祖先symlink→还原→fresh成功的实际反例。最终冻结源原CLI实测107/26.802秒，process27.034秒/exit0/60秒cap，完整raw及前后3个保护源SHA一致；此前29.380秒观察缺raw与Windows补前的局限单独保留。独立21项/路径等价及最终日志审查见review04/05，最终新CI仍待。

本机一次去重错误使固定可写aim_save输出与两历史文件共用inode，随后真实测试更新了历史路径。已从两份未改写的Git原始ZIP精确恢复两原件并将可写输出隔离；全1870路径核对仅current raw合法变化，另212个潜在可写路径断开。此为真实保管失败及恢复，不能称原去重安全。原件、SHA、恢复方法见`evidence/parallel_integration_01/custody01/`；现行测试与历史证据未互相冒名。

## 第三候选与最终文档预检

ff143c91的push docs39232313993中，生产原107项实际39.996秒通过；随后路由24项/16errors因旧总谱的20%/旧controls权威被正确拒绝。准确ZIP artifact12178082160/SHA4085967e50a2f3449c028a4faeff4d644afbd8e636b0b5666c3503a4762dad8b保留。full39232336288终态cancelled、未发布，不标完整通过。

现沿既有总谱schema升级两active creative-v3，完整归档旧v2字节/SHA，旧版用当前权威仍被拒绝；正式Plains对应PR91像素，森林对应v12/15%/挂环及REVISE。旧P1/PR90配方与素材没有升为当前默认；generic美术planner仍走旧候选，当前像素生产用途明确blocked，本轮不执行这类mission。原校验器未改；当前版本精确断言更新v3，新增原v2身份/bytes/拒绝反例。相关专项2方向/10creative/原24routing全通过。

本机原docs Harness --release一次完整24项实际PASS，原收据/全stdout日志无损ZIP在`evidence/parallel_integration_01/docs_final01/`；这是工作候选的本机证明，不冒最终CI。两原生正常速电影真实源ff143c91，2038/1769帧、60FPS、无注入/手动Motor、严格source_stable；后续只有docs与独立Python版本测试变动，2716项采集库存仅该非运行Python测试不同，运行/电影驱动零字节变化，最终Git绑定另验；绝不改签raw影片源。独审实际看8原AVI样帧，限定角色/树壁/环可读，没有全片听音或玩家认可；map2 HUD边缘可读性候选未证新回归，仍未签商业美术。见`movies01/`及review06。

## 本轮新增PR93

远端复查发现09:41新增PR93，基于已整合PR91，按增量纳入。02cd原push docs39235403208实际24项PASS且Windows成功，但full39235453618为纳入新输入主动取消，不称完整通过或新发布。其原生影片仍明确绑定ff143c91；新增菜单/App实验入口后不再声称最终运行文件零差异，也不改签影片源。新源将复验StyleLab原玩法与Biome/CLI、共享表现与战役UI，再跑完整发布门槛和线上GUI。

PR93原生路线17215/0、Biome1706/0及3CLI实际通过；共享表现36/0（含真实Lab并开拒绝/退出）和原战役UI56/0通过。Lab不改变正式地图池。新增3loader有限资源适配以精确SHA绑定66个实际资源（总known333）；quality原45+6新反例51/0。11资源承载严格区分CC0、自定义许可与生成unknown，visual均未验。原218路径质量记录缺项FAIL保留；补affected_paths后另验，不豁免。另一次原生presentation因磁盘耗尽exit120失败，恢复工具、移除无人使用的孤立临时Git pack后02完整exit0，日志另保留。

## 第五候选d86真实失败与整合缺口

d86完整39237985979终态FAIL，未发布。Web/Windows/push docs24通过；两lane实际24通过/2失败/其余未执行。scene发现新像素景观遗漏四场所身份，木台消费者仍假定旧shader，浏览器原第一消费者固定坐标误入新增StyleLab；不是凭CI绿色代签。原件见`evidence/parallel_integration_01/ci05/`。正在用真实新像素四地标、明确current/legacy绘制器消费者及可见label/真实pointer导航修复，原物理/断言/原预算不降；新源完整验证另跑。

## 第五候选之后的有界修复

当前像素景观新增程序绘制的风车、井、钟架、维修架四种原始轮廓，依实际Manifest身份、StaticBody支撑与保护区放置，不改变几何/RNG/玩家。原scene完整wrapper实际255.886秒通过，原8路线、10真实变造和12伪造验收例保留；新绘制器通过真实Sprite观察，原判定不降。完整31成员无损归档和正常zoom两图八幅独审见[修复证据](evidence/parallel_integration_01/ci05-fixes01/README.md)。地标局部可辨但偏小、背景抢眼及浅色顶边误读风险仍列局限，不签整体美术终审。

当前pixel木台严格验class、完整bounds、一对一body/oneway，原shader check_module逐字节保留并在同正式几何的显式legacy生产fixture执行，默认游戏不恢复旧风格。headless1747/0、实际GPU1760/0通过；原LegacyStrip负例真实非零失败且保留，非把负例失败改成游戏PASS。

原d86包配严格可见label导航后，桌面真实进入ACTIONS并一次装备通过，小屏844×390内容与thumb真实拖动均失败。Godot4.7.2 ScrollContainer只处理鼠标/Pan，BaseButton能直接处理touch，项目全局touch转mouse关闭；因此是生产菜单触屏可达性缺陷，新UI适配与新包另验，不能改消费者让旧包过关。[真实导航失败与源码定位](evidence/parallel_integration_01/navigation06/README.md)。

## 触屏菜单与历史展示合同收敛

菜单只在可见ScrollContainer内转发真实触摸到正常GUI鼠标通路；按钮PASS让原生父滚动收到事件，保留Slider STOP、根面板拦截与全局输入关闭。ACTIONS恢复普通18/46，FontVariation保原Latin并补已有OFL中文fallback；实际43原生断言及两个GL中文合屏通过，早期dirty Web10手机取消/滚动/导航/一次装备通过，最终同源Web72/公网20项8入口仍待。OCR完整标签同baseline合并并统一真实bbox唯一性；原误收反例、旧失败07-09与修复独审均保留，不能用native代手机。见[菜单证据](evidence/parallel_integration_01/menu-touch01/README.md)。

冻结前原4旧画风wrapper发现真实缺consumer，均按原工具预算留FAIL；autonomy实际已有冻结v9回归PASS，未错误重做。四旧renderer改为唯一test-only显式legacy profile fixture，原153条断言、负例、两环境、GPU和预算逐条保留；在真实current Stage安装前确认Pixel默认/无旧consumer、缺错flag拒绝，前后签Manifest/真实多边形和形状参数/玩家调优不变。正式Pixel生产Stage不恢复旧画风，当前scene8真实路线10变造与pixel-formal另验。首次类型错误、第二轮ferry负例原90s超时保留；仅waterworks复原真实旧ferry shader，原完整两suite后续复验。见[真实失败与分版本来源](evidence/parallel_integration_01/late-style01/README.md)。

存储仅对旧无活动引用生成API缓存195文件作55blob无损保管，完整映射/解压SHA+CRC后移除冗余原件，净回收约459MB；原字节ZIP保留本机，Git不冒称携带178MB缓存包。此不涉及当前共享cache/源/电影或玩法证据；旧去重149路径按新收据接管。见[保管范围与可恢复边界](evidence/parallel_integration_01/storage03/PORTABILITY.md)。

## 第六候选冻结前结论

最终ready05原connected完整wrapper实际10.505秒通过：23断言/0失败、3株真实植物，完整源码守卫一致。原153检查与四预算/env AST独审保持；review02限定接受，未将分来源terrain/direct/visual/connected拼成最终同源98通过。validation04 ZIP七成员均逐项SHA/bytes/CRC验证。最终冻结源码完整CI、原包72、公开20/8尚待。

输入五分支于12:14 UTC复查保持所列精确head。原第五候选FAIL、所有局部失败和不同source边界均保留。接下来冻结新提交，只用其完整gameplay/art 98项、准确CI Web原包72、Style Lab实际入口和公开GUI20/8及完整PCK判定技术交付；正常原速影片另做同源新片。整体森林体验与真人/设备仍REVISE，不因技术通过升为商业完成。

## 第六候选原包采证失败与停止

精确候选afd84ec6/CI39253468792的Web、Windows与push/PR docs均成功，push原24项333.753秒；准确WebZIP与完整PCK核验通过。原coordinator56.5595秒真实失败于清晰可见ACTIONS被全幅OCR漏掉，72动作断言未开始；root在部署前取消剩余lane，终态cancelled、无完整98收据、不称98通过。准确同包独立Style23原23项实际PASS。候选6原native单路线186.522秒/1769帧60fps/source_stable并完整无损AVI+MP4/原样帧独审通过，仍只签单路线。见[完整失败、局部通过与来源](evidence/parallel_integration_01/ci06/README.md)。

发现新增Lab使DEV在标题页折叠，公网工具尚未实际运行，不能编造公网失败；collector仅改原有限真实scroll启用。完整按钮像素ROI方案在桌面实际通过后，首手机live11因抗锯齿不同边色真实FAIL；中文模型和Nearest重采样诊断未解决，均保留。后续只用真实背景/16实际锚色的alpha混合捕获边框，四边/完整label/全局唯一性/原5观察和各300、公开480预算不降；固定6xLANCZOS重采样需实际双viewport与独审，再冻结新候选。正式游戏/runtime无改动，新源完整CI和准确包72/公开20/8另验，不通过静态反例替代。

第七候选采证修复限定独审已接受：最终c722…完整border/alpha-mask与固定6xLANCZOS下原桌面、原手机PNG正例及四真实像素负例、36候选溢出均正确；live12桌面和844×390手机fresh Studio/一次装备及手机DOM取消后导航实际PASS。原72/公开检查未改断言或预算；这些仅同CI6包dirty工具专项，新source完整验证仍待。见[保留失败与最终有界接受](evidence/parallel_integration_01/collector07/README.md)。
