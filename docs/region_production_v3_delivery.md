# 风铃平原 V3：实际交付与未完成范围

**整区商业级手绘美术仍为 REJECT，完整自主地区制作能力未完成。** 本轮实现了有限空间资产升级、RootBell 真实遭遇切片和生产链修复；技术回归、局部像素接受与玩家/设备认可分别记录。

完整新增/修改路径见[质量记录 affected_paths](quality/records/PLAINS-PRODUCTION-V3-01.json)与[PR文件差异](https://github.com/zhipijun1996/gunman-rush/pull/69/files)。

分支 `feature/plains-production-v3`，[草稿 PR69](https://github.com/zhipijun1996/gunman-rush/pull/69)，继承 PR68/67，不合并 main。当前 D 代码为 `50fb10c749871cb555f24fab84b3f539abde49fb`；后续原件归档和仅诊断补丁不冒称已导出的游戏源码，也不表示已经部署。本轮仅推进平原，不再启动森林设计、制作或演练；历史 H-only 记录的 `content_complete=false` 不代表森林开放或能力授予。

## 当前版本验证与发布状态

| 项目 | 实际结果与证据 |
| --- | --- |
| 完整 D deliver | **原入口完整12/12步骤实际通过**，全部子步骤exit0；gameplay/art57项、web25项均fresh/reused0（两集合有重叠），原全局源守卫通过；[完整原件与独审](evidence/region_production_v3/final_delivery_50fb10c/README.md)。各子步骤运行耗时合计约57.68分钟（不含步骤间检查等开销），不代表设备/玩家/商业美术通过 |
| 当前 D 本地 Web | build_id `42cdac2ee80e`；实际 PCK 85,319,148 字节，SHA256 `42cdac2ee80e885da58f97cd251a2cf0d2c6a03a51575f4da6bc32a27e41b3dc`；build-info 的 source_commit 为上述完整 D SHA |
| 公开 HTTPS | **blocked，尚未部署本轮新版**：最新CI attempt2的terrain-family-tests失败，deploy/verify_public被跳过；实际公开站点仍为旧PR67 build `3dd966827a31` / source `2c2904172045017037e4110323c1097f9d24c5ad`。不提供冒称V3的新HTTPS链接 |

当前 D 的真实 Title→Home→升级购买→重载→正式随机平原→地图/移动输入路径完成 **9 项 GUI 检查**，invocation 前后源指纹一致。使用隔离档案一次性置入 **9 音符夹具**，真实花费5音符购买 vitality 1，重载仍有4音符/升级，正式入场 **HP6**；不是最弱构筑，也未证明通过游玩赚取音符、完整区域遍历或打赢 Boss。地图打开/缩放/拖动/关闭、普通跳跃移动与后坐力输入均留原图。浏览器日志中的 favicon.ico 404 保留，不称“零404”。

该次实际录屏为 **106.44 秒、2661帧、25fps、1280×720**，正常时间轴转码且**没有音轨**；MP4 SHA256 `3bd675ab73acb3432c8243c9f2258494a6a0786c1cec700907e36e3ca363b6ec`。只读 WebAudio analyser 观察到非零输出，不等于人耳听音验收。Chromium touch emulation 不等于 Android/iPhone 真机。原件现位于 `build/region_production_v3/final_native/formal_web_gui_final01/`，不同作者最终限定复核已接受完整原入口；本地最终导出build-info/实际PCK指纹与该GUI包相同，源SHA与全局指纹也一致，[当前D原件](evidence/region_production_v3/final_delivery_50fb10c/README.md)保留完整报告、日志、截图与录像。软件GPU动作电影另有2300帧、38.366667秒/60fps和48kHz立体声音轨，只是已接受输入的动作技术覆盖，不冒称平原全域游玩或人耳听音。

## 有限内容与品质边界

| 内容 | 正式消费者中的实际范围 | 未完成/失败边界 |
| --- | --- | --- |
| 维修工坊、钟庭 | 完整330世界宽工坊有真实支撑；钟庭接正式场景链并有独立实景 | 原500宽工坊失败保留；fast 对照片未进入钟庭 |
| 风车高地、挂藤 | 完整146宽风塔，20图11建/9省略；挂藤沿真实静态/单向支撑，20图76挂接/66省略 | 240/200风塔规格失败；无合法支撑便省略，不重抽、不外推任意形状/移动平台 |
| 岸端、天空/远山 | 限定岸肩、天然岸端和铜石板采样；独立天空/远脊连续横纵视差 | 不是完整岩壁家族精修；不合格树林停用留下中景缺口，不算画质提升 |
| RootBell | 在已物理验证的620宽 double_gear 类最多替换1敌人；避标记脉冲、跳出返回、真实弹体打断/击杀 | 40图仅1处符合，入门0/20、进阶1/20，不是全区生态完成或出现概率估计 |

独审实际看像素，接受这些限定用途和挂藤修复，仍拒绝整区商业品质：重复矩形岩壁、旧细柱/风车支撑感、中景不足、空天空、Boss 美术和完整视听尚有缺口。RootBell 使用两张完整图集、GDScript region 和既有 CC0 声音，无虚构新裁帧PNG/原创音效。Boss 保留原玩法；两次新美术失败未进入运行时。[最后岸体尝试](evidence/region_production_v3/supported_bank_failed_independent/review.md)同样未获准入，未裁图、补alpha或降低门槛；失败源及 STOP 家族保持隔离。

核心 Motor、武器/输入/资源、能力成长、RNG 服务和保存 schema 未为画面让步。**RunManifest/DemoApp 源码确有 v10/v11 绑定与回放兼容修复**，正式内容为 `plains-region-v11-root-bell-v2`；未知未来/混版本拒绝，不新增磁盘保存服务。

## 可观看证据与路线结果

[PR68/V3 原始对照片及完整原件](evidence/region_production_v3/canonical_route_comparison/README.md)为正常时间轴1280×720/60fps：PR68 `ed0623000c61287282f89e6b0463937b0afe0aca`，V3 改藤前 `21e27bda8031d1b7122257c900479647f1cfbf31`，改藤后 `1d1ccadc2649b145b58c1489a439ffc687b5877c`。它们都不是当前 D 重录；精确 source_before 清单随原件保存，commit 标签本身不是完整指纹。

同 literal Seed `level-design-v2-baseline`、map2/fast、`kill_from_bank_v1`，两侧3063物理tick/7段、3067视频帧到路线目标；逐tick位置、速度、输入、HP/能量相同，没有逐tick相机数据。PR68→V3 原严格纯美术比较仍 **REJECT**（Manifest/RunManifest/驱动来源差异保留）；只有同v11挂藤前后严格通过。片中覆盖高地、维修营地、主岩壁和下层溪谷，不覆盖上层钟庭/Boss。[挂藤后独立像素审查](evidence/region_production_v3/final_after_ivy_visual_review/README.md)打开27张新帧/6张旧帧并验证3张MP4解码帧，未冒称完整播放/听音。

[RootBell 正式默认遭遇录像](evidence/region_production_v3/final_default_movie/README.md)源码为 `b5b9be26357906333bdf53990a93935e5dbfd7e5`，早于挂藤与当前 D：实际15案例、5145物理tick/5149视频帧、9脉冲，含0/30/60等待、出返程、两次真实弹体打断/死亡、死后经过和齿轮走廊返回。不是完整战役或当前 D 全域证明。

[80路线原件](evidence/region_production_v3/final_multiseed_80/README.md)及[不同作者复核](evidence/region_production_v3/final_multiseed_independent/review.md)：10Seed×两图×4策略，80份采集完整性有效，**71到驾驶目标 / 9策略失败**；26旧回执核验复用+54新跑，6个Git版本的798项原生源投影逐blob复建，不冒称 D 新跑80次。71为fast20/growth20/deep15/return16，目标不是Boss/整局通关。9失败均在map2高收益探索，8安全岸反冲守卫、1无伤害进展，失败时HP5；两条额外诱导也失败掉血，既不证明地图无解，也不能全部归为策略误报。矩阵20张地图 **RootBell为0**，其覆盖依赖前述专用证据。

[opt-in v2 驾驶实验](evidence/region_production_v3/kill_bank_v2_independent/review.md)只在seed03/map2/deep改善一次静岸击杀搜索，随后仍四次fan交叉伤害至HP1；最终奖励回血/到目标不消除失败段，不设默认、不改71/9。原9eef标签实际附806项逐case源投影及dirty overlay，不能称clean9eef；与原矩阵对应case亦有172处进程owner/别名差异，不称raw完全一致。

## 生产链与技术验收的限定成果

沿用现有 Harness、production_loop、G0–G5/十一维与专业 Skills，无第二套质量架构。已修租约撤销/到期复核、调用前依赖/权限/外链预检、post-draw生成新输入（100ms TTL不变，真实130ms仍拒绝），并保留原失败、调用消耗和独立审查。Hash/metadata不代签像素、趣味或用户认可。

- [版本回放修复及独审](evidence/region_production_v3/root_bell_run_replay_independent/review.md)：原campaign3705项从3失败修为0，5回放正例/9负例；原断言保留。mini-Boss outcome/item fixture 不冒称输入打赢Boss、自然奖励或磁盘保存。[G1 原入口](evidence/region_production_v3/root_bell_g1_routing/review.final.md)真实消费原165/41/9、strict27+9、40图和11收据反例；139 Python探针不是139次原生执行。
- [真实PCK闭包独审](evidence/region_production_v3/web_raw_closure_independent/review.md)：有限editor导出插件保留7raw/12texture/8JSON，七个真实删raw目录项反例均拒绝，四STOP家族/插件源码不入包；原43+新2测试已接art/web/full并经[真实Harness路由](evidence/region_production_v3/web_raw_closure_independent/review_routing.json)执行。三preset配置一致不等于三个平台实际包均已验证。[来源审查](evidence/region_production_v3/asset_provenance_independent/r2/review_r2.json)覆盖已知字面消费者，保留字符串拼接路径未识别反例，不是通用GDScript可达分析。
- 旧背景消费者修复保留原断言/物理攻击/timeout，另测真实当前默认：[Painterly 204/0](evidence/region_production_v3/painterly_consumer_independent/review.md)、[Pressure 189/0](evidence/region_production_v3/pressure_background_consumer_independent/review.md)，撤旧选择器仍实际失败。v11分析器原24测试AST保留、最终30/0；早期None身份漏洞、合法JSON1.0和旧receipt source_changed均留原件，最终fresh三条assembler-noenemy路线不冒称战斗证明。
- [遭遇原入口fresh独审](evidence/region_production_v3/encounter_policy_boundary_independent/fresh_native_acceptance.json)：旧v9/当前四组因精确两项core SHA差异仍 strict **not_comparable**，比较器未放宽；另一次独立currentreturn真实采集才构成严格同源正例。原5native/7causal/8claim与活敌非击杀反例全执行，不是内容改善或9失败已修。

历史失败统一保留在[最终失败归档](evidence/region_production_v3/final_release_failures/README.md)与[91f65候选原件](evidence/region_production_v3/final_release_candidate_91f65/README.md)：包括旧generated-consumers/背景断言、旧Web缺raw、RunManifest和v11分析消费者拒绝，以及完整deliver **47通过/1失败**。后来的专项通过不改签原失败。CI38831828144 的core实际36分33秒在分析版本处失败，Windows/Web成功，并非job timeout；core总job预算40→60分钟仅为完整串行执行保留余量，每项timeout、断言、选集不变，当前D的[实际CI38839225917](https://github.com/zhipijun1996/gunman-rush/actions/runs/38839225917)已全部适用检查成功；分支push的部署为skipped。手动发布[38846504655](https://github.com/zhipijun1996/gunman-rush/actions/runs/38846504655)的attempt1在core/web下载1.2GB模板时curl28超时、未开始测试，部署被跳过；同SHA的一次有界rerun--failed为attempt2：Web/Windows成功，核心terrain-family-tests失败，部署与公开核验被跳过。此前同源绿色CI与本地完整通过仍保留为历史真实结果，不能冲销新失败。

Foundry 56份JSON刷新仅basis/hash，54份replay frames逐字段未变，36短语/18itinerary不是54条新动作。容量修复有同字节硬链接/SHA与恢复记录，保留失败电影和原图；只清理明确idle可重建cache，外部/tmp仅暂存可重建工具链，不把剩余空间当回收量。

发布观察仍有实际缺口：首次发布因模板下载curl28失败；同一run有界重试恢复。其后本地状态查询曾遇短暂401而退出，当前宿主按同一run/source/attempt有限重连继续，没有重复派发工作流；原失败日志与恢复脚本保留。现有通用publisher尚缺正式resume入口，不能把这次宿主恢复说成完全无人值守系统已经成立。

## 下一次平原任务如何启动

沿用现有入口，以简短需求生成既有Harness可读任务；执行需要当前真实Codex宿主读取请求、调度专业实施和不同作者审查，不是独立后台模型服务：

```sh
python3 tools/level_design.py route --request "优化风铃平原的美术与探索体验" --output build/plains-next-mission.json
python3 tools/harness.py --mission build/plains-next-mission.json --execute --worker-mode host --evidence-dir build/plains-next-production
```

本轮实际验证了租约、失败返工、原生回放、来源审查和有限资产/遭遇集成；仍未证明仅凭该入口就能自主达到整区商业品质。短指令无需用户重述已确认世界观、能力和美术规范；现有正式规则、失败经验和真实消费者必须自动读取。本轮不重新执行森林任务。

## 最新发布阻塞与诊断修复

当前V3 **未上线**。attempt1在模板下载curl28失败；attempt2恢复下载后，核心57项中实际55通过、terrain-family-tests失败、最后forest-h-slice未执行。原始远端wrapper只打印失败目录，上传的artifact也遗漏内部report/native logs，因此远端具体根因尚未确定，不称为网络问题或已确认的偶发错误。

已给现有terrain wrapper增加失败原因/有界内部日志输出，并将其原始目录加入既有CI artifact，不改变原断言、argv、timeout、负例和source guard。补充本地运行实际复现正例45/0但退出resource ERROR被严格守卫拒绝；这证明诊断可用，不证明远端同因或根因已修好。原精确all-maps专项与不同作者审查另有原件，最终结果见[最终归档](evidence/region_production_v3/final_delivery_50fb10c/README.md)。

现有实际[Web构建下载](https://github.com/zhipijun1996/gunman-rush/actions/runs/38846504655/artifacts/12023882984)（189,345,058字节）与[Windows构建下载](https://github.com/zhipijun1996/gunman-rush/actions/runs/38846504655/artifacts/12023587199)绑定源码 `50fb10c749871cb555f24fab84b3f539abde49fb`，不是已上线手机Web预览。GitHub artifact下载需要登录且有保留期；本次下载遇403，未独立读取远端ZIP内部build-info，不能将本地build_id直接挪签为其内包指纹。本地42cdac2ee80e包与正常GUI/影片是确实已验证的另一明确范围。

## 未验事项、预算与下一步

RootBell/完整路线仍有 ObjectDB/resource 退出诊断（版本auditor20/17），未签生命周期清洁。llvmpipe录像CPU/GPU平均约48–55ms且监视器重叠，60fps成片不等于设备60fps。真实手机/手柄、完整听音、最弱构筑的当前 GUI 路径、用户趣味/审美和商业画质均未验。

本轮有界窗口为2026-10-16 01:02:25至13:02:25（北京时间，UTC+8；原始证据保留UTC时间戳）。实际图生/编辑 **14/18**，原生产host **44/44**，失败/中断不退款；接续直接工程/独审另有代理记录，不称44是所有provider调用。token、单价及部分调用时长未暴露，不编成本；并行时长不相加为墙钟。Boss、树林、岸体及共享渲染对应失败/停止边界保留。

后续应先解决完整自然岩壁/连接结构与有根中景植物，按同Seed真实镜头准入；同时定位退出生命周期并在实际手机量测渲染成本。扩大公平且判断不同的遭遇空间需独立黄金验证；不以稀有1/40冒称全生态。森林待用户认可平原后另起，不在本轮追加。
