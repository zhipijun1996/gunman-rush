# PR69 生产能力修复：有限成果已交付，完整发布 BLOCKED

本轮从 PR69 `4f2066fd610faa1b86de5a942fa7c1c0bdacda26` 出发，草稿 [PR70](https://github.com/zhipijun1996/gunman-rush/pull/70)，不合并 main。最终工程源码为 `fe84b4937347c8f8dd43f2c916f84689fa87cd8b`；后续提交只整理证据/状态，**该源没有完整成功 CI、没有正式导出、没有上线**。自然连接岩壁未达原艺术目标并停止；普通地图的新生态/植物覆盖仍未改善，不能称完整自主区域生产能力已修复。

原全地图 terrain 专项在最终源实际严格通过：428/0、真实破坏反例47/1，均按预期native0/1且退出干净，内层24.747618秒。但完整 encounter 的真实物理反例仍额外泄漏20个ObjectDB实例/7个脚本资源。不同代理的[最终独审](../../evidence/production_capability_repair/final_blocked_checkpoint/FINAL_REVIEW.md)判定整体 **BLOCKED**，仅接受有限工程/植物/两类空间。未放宽门槛，也未继续用完整CI碰运气。

| 交付对象 | 实际结果与准确来源 |
| --- | --- |
| 最终源码 | `fe84b49`；原terrain专项、有限快照/兼容修复有真实正反例；完整encounter未解决，因此没有第三次CI/发布 |
| 最近正式CI | [38875599430/attempt1](https://github.com/zhipijun1996/gunman-rush/actions/runs/38875599430)，源码`9ffe8e7`：30项通过，plains-action-golden失败、后30项未执行；Windows/Web成功，deploy/public跳过 |
| 保留的真实新Web包 | [artifact12035647459](https://github.com/zhipijun1996/gunman-rush/actions/runs/38875599430/artifacts/12035647459)，源码`9ffe8e7`，build`8db51abc2fef`；实际原包三浏览器消费者72checks通过，263个served文件前后不变。它不是最终`fe84b49`包，也未上线 |
| 实际公开站点 | 最终HTTPS metadata GET仍为旧PR67：source`2c2904172045017037e4110323c1097f9d24c5ad`、build`3dd966827a31`；这次只读metadata，没有下载完整公开PCK，不能签本轮公开包通过 |

保留Web ZIP的API SHA256为`bd1f368028eb5ba87d394fd807d84e4fcdbf0950818b3d1bcf30922f41153af5`；实际PCK为89,927,820字节，SHA256 `8db51abc2fef0695ad63fa1f6803237e09a2514024864093ee25bcd589bc89e6`。该PCK的原PNG/JSON、导入目标/实际ctex及完整chunks已独审；不声称整份`.import`元数据与本地相同。失败cliff v1/v2及派生纹理不在包。最终源码与A4的scripts/scenes/assets/resources/config/shaders/project/export对象相同是源码等价证据，不能代替最新导出或发布。

同源`9ffe8e7`原生动作影片另有2300条trace sample、2302视频帧/38.366667秒及源前后校验，和CI Web PCK电影分开；没有重签成`fe84b49`影片。[最终便携检查点](../../evidence/production_capability_repair/final_blocked_checkpoint/README.md)集中提供包/日志/指纹、失败、独审与恢复边界。

## 真实产出和未完成范围

[原V3审计](../../evidence/production_capability_repair/v3-audit.md)逐项分类44请求、14图生与有证据的失败。实际独立读取33份原response、27份角色elapsed；9份响应历史曾存在但原字节未取得，另2次原事件没有响应（撤销review、断连实施）。不能捏造44份完成回执，也不能把检索缺失说成provider隐藏。[补充审计](../../evidence/production_capability_repair/audit_addenda/v3-audit-git-metadata.md)保留nonce、Git/OID及存在性来源。

主要瓶颈是素材形体与消费者接口不匹配，根/连接和大轮廓晚验，空间与敌人事后拼装，以及昂贵回归后才暴露的证据闭包、历史消费者和退出生命周期问题。原图生调用数本身不是12小时主要可见成本。

| 目标 | 实际产物与正式变化 | 失败及准入边界 |
| --- | --- | --- |
| 自然岩壁连接 | 两轮AI原画、24格接口/连续母版校准、真实并集端/底实验与游戏A/B保留，校准工具可复用 | 首轮24格gutter全失败；次轮core0.984501＜0.995。周边实验仍有直切、矩形轮廓、缺内凹连接。两轮STOP，最终消费者/三个export preset排除，不能称完整家族 |
| 有根中景植物 | 一张AI原图校准6件完整来源、根锚及等比缩小；真实静态石台支撑/净空solver正式有限使用2树+1灌丛 | 原等分margin/gutter失败照留，另用途区域校准不追认原合同。三消费者接受不等于六件、跨区或商业终验 |
| RootBell联合空间 | 保留620宽双齿轮岸，新增560宽恢复桥紧岸；同卡约束进出动作、落点/旧mark、相邻机关、退路/返程和植物keep-clear，复用原脉冲/打断/活体绕过AI | 至多替换原有1敌人，不加总数/概率。专用40图1/40→2/40，原交付20图0/20→0/20。植物仅在真实RootBell空间构建，普通20图新植物也是0 |

宽岸的双齿轮前后节奏与紧岸深沟/恢复桥返程构成不同判断，而非同挑战换坐标。它证明第二种合法空间，未解决常见覆盖。后续应先联合普通地图的支撑、观察带和退路设计，不能靠加怪补覆盖率。

## 可观看的新旧实景与行为

以下为原始Godot PNG，来自冻结v11宽岸的同Manifest/几何/镜头，仅toggle新植物；是静态重置夹具，**不是v12整版A/B或通关证明**。

| 窗口 | 旧画面 | 新画面 |
| --- | --- | --- |
| 接近：左树/灌丛 | [旧](../../evidence/production_capability_repair/asset_families/final_plants_ab_01/window_0_baseline.png) | [新](../../evidence/production_capability_repair/asset_families/final_plants_ab_01/window_0_candidate.png) |
| RootBell预告/落点区 | [旧](../../evidence/production_capability_repair/asset_families/final_plants_ab_01/window_1_baseline.png) | [新](../../evidence/production_capability_repair/asset_families/final_plants_ab_01/window_1_candidate.png) |
| 回望：树根接土 | [旧](../../evidence/production_capability_repair/asset_families/final_plants_ab_01/window_2_baseline.png) | [新](../../evidence/production_capability_repair/asset_families/final_plants_ab_01/window_2_candidate.png) |

[v12两段真实影片与完整来源](../../evidence/production_capability_repair/ecology/movies/README.md)：宽114.717秒、紧86.417秒，1280×720/60fps；分享版有损编码，不能称与原片像素相同。不同作者实际打开宽16帧/紧14帧的连续窗口，限定接受定点预告、跳过活体、射击打断/死亡后返程中的可读性及三植物用途；未完整播放或听音。[fresh默认证据](../../evidence/production_capability_repair/ecology/final_runtime/README.md)另有来源，不把候选影片改签为最终默认运行。

每片19案例为17个Router输入、1个生产pause callback、1个inactive生命周期夹具。低资源活体完整去回起始能量0、无接受射击、RootBell HP3/玩家HP5；但inactive阶段每片均HP5→4，不能签19案例全程无伤。Router驾驶不冒充真实GUI、完整战役或实体设备。原V3的80路线71到目标/9策略失败也未被本轮有限修复消除，不一概归为驾驶误报。

## 生命周期、工具链与发布：错误分类不混用

旧远端terrain-family内部日志未上传，精确根因仍unknown；本地Ogg复现不能倒签该次唯一原因。本轮定位的独立缺陷及原反例均保留：

- fixed-fps退出早于音频后端释放，GameAudio和无服务时ShotLatch fallback bell为不同owner；使用WeakRef跟踪、有墙钟上限的shutdown drain与正确teardown。no-drain、强保留playback、单孤儿Node/native0的真实坏例均拒绝，不靠固定sleep或吞stderr。
- 纯load即21 ObjectDB/18 script resources的类型/引用问题与音频分开；pin历史夹具仍败，局部显式cast最小正例clean，原await/断言不删。Godot C++内部所有权仍未知。
- 模板curl28按传输有界续传；403、错误SHA终止。发布checkpoint绑定ref/完整SHA/run/attempt，恢复不redispatch、不自动重跑CI/auth。实际公开成功还需deploy/verify_public、API digest、PCK/hash和live指纹。

首次本地deliver（b675）313.966秒中止：生成消费者功能通过，真实退出泄漏被旧外层漏守门。修后第二次（721）486.657秒仍失败：generated-consumers严格过，region cohesion63/0/native0仍4 ObjectDB/2 resources，新门禁正确阻断。此前17套逐一clean不冲销fresh失败。

随后只修实际owner。独审拒绝卸载前await；晚capture也失败并保留。最终在原cancel_pending stop点紧前同步捕获WeakRef，保留原fatal/queue_free/卸载两帧观察后才等待。完整原15套region最终215.015秒严格通过、16源前后一致，独审有限工程接受；不预签完整CI。补读旧V3最后57份日志发现3个外层check中14个子套件已有ObjectDB/resource终态错误（另有RID），**旧57.68分钟只代表旧门禁通过，不能写clean**。已修入口的新鲜、缓存及所审重定向/嵌套消费者均拒绝精确生命周期终态。

[A3 CI38872475547/attempt1](https://github.com/zhipijun1996/gunman-rush/actions/runs/38872475547)的prepare/Windows过，core/Web因9个本机build证据缺件在quality失败，未进gameplay、未部署。这是本轮交付遗漏。全查60卡/506证据只缺9件；29,545,901原字节无损gzip为1,485,131字节，逐字解压验证，原source/方法/失败不改。新增精确commit Git树闭包守门，旧A3负例0.083918秒找出9件，A4正例0缺；独审在无旧build的真实独立sparse checkout亲跑原quality过。

A4通过前述闭包后又在plains-action-golden失败：冻结484资产中仅 assets/manifest.json 当前字节变化，旧恢复器错误要求它等于历史文件。这是快照重建缺陷，非网络或偶发环境。修复保留原冻结manifest/archive/成员指纹，以81,391字节原Gitblob sidecar恢复唯一变更文件；真实浅克隆和缺失/损坏/错指纹反例验证无历史/网络依赖。准备阶段先检查，原三个原生消费者仍必须执行。

三个真实消费者的后继专项又暴露旧GameAudio无shutdown接口、静态32/0后land.ogg退出泄漏，以及遭遇策略原预期物理失败后的20ObjectDB/7resources。最后一类verbose列出悬停的GDScriptFunctionState/Trace脚本，不能混称Ogg或纯load。新helper初版还遗漏source inventory传递闭包并实际KeyError，此次返工也保留，不能归为环境。本机sparse缺两个已跟踪历史文件则单列准备问题。精确资产恢复、旧API4711帧正例和原autonomy32/0+浮空3fail/native1已严格通过。完整encounter物理反例仍20/7；专属terminalNode取消候选在真实任务中失败并撤回，最终未修改原level_formal_trace或物理反例去掩盖它。

A3、A4是不同源的两次正式CI，各一次dispatch，无同源rerun碰运气。预留的最后一次新源CI最终没有启动：独审指出新取消传播会涉及忙循环和额外Router请求风险，范围内没有已证安全修复。生产窗口已关闭，后续仅证据整理/静态复核，未放宽质量或无限重跑。原两次CI失败与两次本地deliver失败不抹掉。

## Harness与效率比较

实际selected checks/知识/质量证据依赖在派工前预检；失败短专项停止本任务后续昂贵步骤，无关家族继续。任务cap与两轮停止、独审/发布预留落在执行器，不只修改Skills。缓存初版曾被独审拒绝：jobs1只归档空目录；修后真实execute→复用→改/删产物必miss，源/命令/工具链/完成标记、归档SHA/live输出/祖先symlink均校验。

原production_loop的连续校准任务实际完成实施及不同作者审查两个租约，同源恢复0新调用，源漂移反例拒绝且不退款。只证明工程stage；原core仍exit1/content_complete=false，不能拿2调用对比旧44称全项目提速。写分享MP4期间source guard中止、稀疏准备和调用错误均保留，不都算产品断言失败。

| 项目 | V3真实基线 | 本轮已证实范围 |
| --- | --- | --- |
| 图生 | 14次；13次tool wall636.724秒，首次精确API时长不可见 | 两家族3次/193.8秒；岩壁两败停止，植物三消费者有限准入，范围不同不报提速百分比 |
| 覆盖 | 专用40图RootBell1处；普通20图0 | 专用2处；普通RootBell/新植物均0，未完成常见覆盖 |
| 本地交付/生命周期 | 子步3461.096秒/57.68分钟，gameplay/art2593.982秒；旧门禁藏14套退出错误 | b675中止313.966秒、721失败486.657秒；修后原15套region215.015秒，不是完整成功或同范围提速 |
| 工具链 | 旧210.119秒终止未装完 | curl28在180秒保留1,147,880,236B，续传23.596秒；安装217.618秒、暖检0.128秒，失败与完成不作速度比 |
| 发布 | 旧门禁本地包；最终CI失败未上线 | A3闭包失败已修；A4又在frozen-v9 manifest失败。最终fe84b49仍被encounter协程阻断；A4实际包三browser通过但未上线，公开仍旧PR67 |
| 阶段成本 | 27/44角色elapsed含工具/等待并重叠 | 已观测区间并集6267.743秒；独占纯模型/网络及未记时间未知，部分事件不冒充全项目 |

最终[闭窗阶段表与效率比较](../../evidence/production_capability_repair/final_blocked_checkpoint/costs/阶段成本与效率比较.md)使用closed_blocked_observed_costs模式，明确full_release_accepted=false、complete_project_total=false。生产窗口已记区间并集6267.743秒（104.462分钟），不是项目总工时；返工标签区间并集3068.638秒嵌套其他阶段，不另加。最终证据打包/文档静态复核在此冻结成本快照之后，另留原命令日志，不伪造闭窗后的完整总量。旧as-of只作历史，不挪签成功。阶段报告分别记录角色实施、图生、实际集成、验证、独审、返工、网络等待和发布，区间和/并集/重叠分开。elapsed不等于纯推理，图生与返工可重叠。token、价格、具体图生model、纯模型compute及内部独占网络等待未暴露，不编数字。

独审接受下载/恢复、特定生命周期/证据闭包、三植物和两物理类的有限范围；缓存、单数ObjectDB漏守门、卸载时序等旧REJECT与修后接受并存。**完整自然岩壁、全域商业画质、普通路线生态覆盖、整片音轨、玩家趣味与实体设备仍未完成/未验证。** 最终发布未恢复。下一任务须先设计并实证observer取消/释放，在不改变原HP/输入/diagnostics/卸载观察、不产生新accepted input的条件下使原反例严格退出；之后才冻结新源跑完整CI、同源包GUI及完整公开PCK验真。当前任务blocked/in_progress/review分开保留，不按完整内容done收尾。

最后文档/证据工作树的原docs+quality fresh通过，命令包络8.816874秒，另留[原件](../../evidence/production_capability_repair/final_blocked_checkpoint/final-static-verification.json)，不并入此前闭窗成本或签完整游戏通过。
