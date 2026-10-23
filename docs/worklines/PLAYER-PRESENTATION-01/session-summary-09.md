# PLAYER-PRESENTATION-01：本会话总交接

本会话累计实现快照为 **631f437a3404e98cdf017d6a2709ed6399533a7a**，基线 **e9ab0e0743466b8983e34cc7de17bab1abf9d53a**；开发分支 **feature/player-presentation-01-motion-candidate**。总清单[session-inventory-09.json](session-inventory-09.json)逐项登记原23提交/459文件的分类、路径、字节SHA及受保护文件对照。本次收口在该快照之上只增加本说明/清单、3项skills/模板文档调整和质量/独审记录，不重录或重标旧运行源。

未合main、不强推、不压平历史或删除失败；没有将其他代理的同ID M1分支合入。M1权威枪口/共享绑定决策仍见[远端已有工作](remote-handoff-01.md)。大型Web ZIP与缓存留在build，其源码/完整SHA收据和必要电影/原始测试证据在Git；不能把本地大包说成已提交或已公网部署。

## 本会话所有修改的组成

| 范围 | 实际变化与入口 | 状态/限制 |
| --- | --- | --- |
| 正式消费者审计/公开方法研究 | [checkpoint-01](checkpoint-01.md)、[methodology-01](methodology-01.md)、[methodology-02](methodology-02.md)；真实Home三外观及Plains基线，盘点身体/武器/锚点/accepted事件与旧消费者 | 发现卡recoil、pixel显示与Home选择不一致等真实缺口；提案不冒充已接入共享角色 |
| 身体/动作候选 | motion_candidate.tscn，motion_visual/profile/feel；独立idle/fall各6帧、下落围巾上扬、旧run按实际位移推进、跳跃/落地尘效 | [motion交接](motion-handoff-02.md)；新run两次失败、握持衔接和完整M1未完成 |
| 起跳/落地/高落差反馈 | landing_feel.tscn，9条CC0音效；真实落地高度+速度条件，短震动及可立即取消的视觉land后摇，原声音池/返回清理 | [feel交接](feel-handoff-03.md)；没有限制玩家操作或新增落地硬直玩法，专用高落身体动作仍缺 |
| 全武器反馈V1及Preview | weapon_feel.tscn，18WAV、弹体视觉叶/接触/束/微光；15装备选择、原Home/正式Plains宿主、CJK和触屏菜单布局修正 | [weapon-handoff-05](weapon-handoff-05.md)；V1保留，不外推全部技能GPU品质 |
| 全武器反馈V2 | weapon_feel_v2.tscn；Freedoom BSD42WAV/真实阶段loop、提交敌伤叠层与墙/落空分离；可见高速飞回刃/离子束粒子/黑洞暗核与内吸/独立爆炸；producer限定hook、实际drop/preempt计数 | [weapon-handoff-07](weapon-handoff-07.md)；9Mode原生片、15normal+6技能玩法专项；正式共享采用与听感仍待验 |
| 用户明确的玩法例外 | magnetic_mine和magnetic_storm的实际6秒引信与寿命；实体到期原explode一次；失宿主先取消 | [mine-fuse-contract-v2](mine-fuse-contract-v2.md)；原4秒无声退役已改变，完整正式影响回归归总控 |
| 定时“滴滴”V3 | 新CC0电子timer一声85ms；V2浅复制bank后三槽同一声音，原age加速；11声实际录音与旧/新对照 | [mine-beep-handoff-08](mine-beep-handoff-08.md)；源4e5102a，未重建/上线新Web，用户听感未验 |
| 原导出必要衍生物 | 原Foundry guard拒绝旧basis后，原build/promote实际重建development池/回放及官方stamp，56个生成文件 | 首次连续重放失败未promote，原池/失败保留，同参数隔离重试通过后更新；不签根因/长期稳定或正式地区池 |
| 验证/资产/交付 | 32个task测试/驱动文件，71个资产登记（含原迭代），74个原证据文件、电影/评审/逐成员SHA、4个独立scene和配置 | 文件数量对应631累计清单，包含UID/导入/历史，不能当成动作或品质计数 |

原7处共享运行改动必须单独由总控看：[完整路径与SHA](session-inventory-09.json)。它们是PlayerController成功提交末尾信号、Projectile普通地形事件、Runtime可选表现/producer音频hook、WeaponDefinition/Entity引信，以及两件磁雷Definition；其余生产以任务目录候选为主。没有改Motor、输入、伤害公式、资源、授予、保存、DemoApp、正式场景、通用GameAudio或Harness。

受保护UnderworldPlayer及三件body资源与main字节一致；PlayerVisualAdapter/CourierVisual也未改。没有自刷旧style SHA。当前Home和pixel正式地区仍实际创建UnderworldPlayer；隐藏Courier只提供部分锚点，Adapter未作为pixel身体消费者推进。家园原三外观选择保留，但不能称完整跨区换装和三角色动作都已实现。

## 哪个版本可以用来复核

| 内容 | 实际运行源 | 可恢复入口 |
| --- | --- | --- |
| 初始基线/消费者 | 817721d等原审计提交所记录main | baseline归档及checkpoint-01 |
| motion修订样板 | 9c69378 / 5ff0c7a | motion-v1证据、motion-handoff-02；不追标最新源 |
| 高落差声音/后摇 | 4ed0de0 | feel-v1证据、feel-handoff-03 |
| 武器V1电影 / 最终V1 Web UI | 5a1c640 / 3a83203 | weapon-v1证据、build b01ee2694450 |
| 最终武器V2电影 / Web | **3254984dcc4f0fc2c3c69b463fe5515f81d69010** | weapon-v2证据；build **6952e7d0d356**，本地完整ZIP/浏览器实际通过 |
| 最新滴声实际电影 | **4e5102af9abd16d322656375e94886a95deae38a** | [mine-beep-v3证据](../../evidence/PLAYER-PRESENTATION-01/mine-beep-v3/evidence-index.json)及[旧/新电影](../../evidence/PLAYER-PRESENTATION-01/mine-beep-v3/timer-comparison.mp4) |

最新滴声公开[电影/来源完整下载收据](../../evidence/PLAYER-PRESENTATION-01/mine-beep-v3/public-download.json)：Git交付e234763下的实际13.5秒先旧后新电影，匿名HTTP200全量SHA已核。V2公开21.7秒片在previews仓库b543242，来源325，不能说含最新V3滴声。最新Web6952也仍旧radio音，不冒充已更新。

最新可操作ZIP：build/player_presentation_01/weapon-v2/player-weapon-v2-preview-6952e7d0d356.zip，167358133bytes，SHA62996c3eddd1fc6a00d204ae8a64e68da904a798be7c52f14e0fb667e6a2aad6。解压运行python3 start_preview.py可操作。公网新Preview多次被900MiB容量守门拒绝；Release401和旧tunnel网络失败留证。没有新公网可玩入口，容量/正式整合归总控。本次是整理，不重复构建这个未变的旧包。

第二仓库gunman-rush-previews当前b543242/clean，媒体提交已推。并发其他工作线入口完整保留；仅本会话尚未交付的fc55中间版无损归档并保留不可变旧Git下载链接，未删除以前交付或其他线的入口。

## 验证事实和剩余工作

最终V2 325原生配对1294×2，各3914检查，28字段和accepted事件相同；全15normal+6earned技能4781×2，各14455检查同样相同。银行458、磁雷123反例及生命周期等详原交接。原Harness2381/1224/7305/2450绑定fc55，不能追标后来4e的新音色。

最新4e原生配对1294×2/3914，各28字段及事件相同、source clean/stable、双方0drop/0preempt；再与旧325 ON跨源比较也相同。实际ready绑定271样本859检查0错，1持久音频服务/3真实Home/重进/Plains叶，新85ms/nonloop及旧bank保留。真实录音4100Hz附近检测到11短段，只是信号测量，不签听感。最初两次绑定测试错误、早期反馈fixture、原源漂移Harness失败、中断报告及Foundry首败均保留，不重写失败历史。

质量记录格式/SHA与diff登记通过不等于内容done。整线仍in_progress，旧visual/animation FAILED、其他未验保留；缺乏全速听看/全部角色与技能GPU/用户/真机/完整正式Integration。中央索引planned同步和共有M1接口由总控处理；稀疏历史缺件导致全库docs/quality检查失败不改签通过。

后继优先级：先裁定共有M1锚点/表现接口及显式共享版本；完成run与握持、正式受伤恢复死亡黄金和全动作/三外观；再实际验证家园选择能否贯穿正式地区，按原完整受影响Integration整合。用户/真机单列。

## skills的有限改进及以后制作外观

本次实改player-creator、animation-vfx及原player_design卡，见[可复用经验和后续Prompt](reuse-notes-09.md)。重点是外观/玩法任务分流、真实连续黄金/锚点、音效语义与实际实例绑定，不新建运行框架、评分系统或额外审批。交付/许可/版本/SHA/旧消费者等已有规则沿用，不重复加一套。

后续期望每个外观有同一份身份/参考、比例/配色、动作矩阵/锚点、实际绑定、正式流程与证据。当前只能说已整理稳定的制作与复核约束；第二个完整新外观还未交付，不宣称任意新角色都能自动一致或已经即插即用。
