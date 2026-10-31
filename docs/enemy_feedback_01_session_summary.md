# ENEMY-FEEDBACK-01 · 会话累计交付与后续生产建议

2026-10-23。分支 `feature/enemy-feedback-01-accepted-sample`，草稿 [PR104](https://github.com/zhipijun1996/gunman-rush/pull/104)，未合 main。本文整理本会话全部累计修改，不继续修改运行逻辑或生成新美术。

累计盘点基线为 PR103 实际合并 `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`，盘点终点为 `620c40b3ca939cd9ba42d5cebcf9b97ccbbcef62`，终点树 `e279c61ac057ac4926cc4407df46389b80265a26`。后续整理提交仅增加文档、清单与质量快照绑定；实拍和运行验证仍绑定 `3003bd0f10ed9c7fe51e0cdc5952aa579a87f130`，不能称本轮重新运行了游戏回归。

## 最终保留什么

| 部分 | 当前结果与入口 |
|---|---|
| 两个代表对象 | `plains_charger` 地面冲锋、`plains_diver` 空中俯冲；不同轮廓与运动方式，原碰撞均28×32，未修改Definition。只做这两个样板。 |
| 正式命中来源 | 原弹体→Damageable→FrameDamagePolicy→HealthState.changed；只有实际APPLIED负增量、唯一event_id、当前epoch触发受伤。接触与拒绝事件不冒充接受命中。 |
| 两条表现链 | `EnemyPresentation` 与 `UnderworldEnemy → PixelPlainsEnemy → WindchimeEnemyVisual` 分别接入同一任务组件；正式安装器替换旧Presentation，所以两条独立验证。 |
| 身体／特效 | 保留受击亮色、较大的短方向尖芒与细粒子；身体材质、HP与预告分层。Underworld采用较明亮的壳／青石／铜材料，Legacy保留自身颜色。 |
| 真实动作帧 | 两物种×两种皮肤，共4套原始PNG、32个绘制姿态；每套4受伤＋4死亡。帧数只是本次实现，不是后续物种统一标准。 |
| 死亡与尸体 | 真实失力／折翼／倒地，落地保留D4；舞台兄弟叶持有尸体，不写父类死亡计时或可见性。支持暂停、支撑释放、epoch／卸载清理。 |
| 幂等与所有权 | 死亡／掉落仍由原Actor和奖励服务结算；表现不结算伤害、奖励或AI，不另造正式事件系统。恢复死体不重播短闪、动画、粒子或死亡声。 |
| 音频 | 被拒的v7自制死亡爆裂声已停止安装，恢复原Actor唯一默认enemy_defeat。GameAudio逐origin可选流接口仍在；旧helper／WAV／工具仅保留可复现历史，不能算当前采用。枪声和普通命中声按武器管理仍暂缓。 |

运行文件：`scripts/enemies/enemy_feedback_01{,_body,_frames,_particles,_remains}.gd` 与任务私有flash shader；宿主为 `scripts/enemies/enemy_presentation.gd`、`scripts/underworld_plains/underworld_enemy.gd`。原始帧、裁区／锚点、alpha审计与来源在 `assets/enemy_feedback_01/frames_v8/`。详细合同见[帧与尸体规格](enemy_feedback_01_frames.md)。

没有修改EnemyActor、Definition、AI、伤害数值、碰撞、奖励、Boss阶段、正式场景、共享材质母版或父类死亡时钟。音频文件的15行累计改动是v7新增的最小流覆盖接口，单列交总控审查，不能说整个会话完全未动音频。

## 各轮去留

| 阶段 | 当时的工作 | 当前处置 |
|---|---|---|
| v1 | 现有系统盘点、正式接受门、双链接入、真实弹体影片；正式池审计后用charger替换旧灰盒巡逻对象 | 基础合同保留；早期巡逻测试不转签最终组合。 |
| v2 | 修Underworld暗像素看不见受击变色、增加共享粒子、清除暂停恢复缓存 | 受击亮色方向保留；旧粗粒子由后续细化。 |
| v3–v4 | 尝试持续尸体、亮材料、更细更大的命中；发现移动支撑尸体读档缺口 | 材料与生命周期经验保留；翻转活图的死相被用户拒绝。 |
| v5 | 按当时“或者爆炸消失”改为碎解；矩形碎片被独审拒绝后再细化 | 被最新留尸要求取代；不继续用消失政策豁免尸体保存。 |
| v6 | 更大方向命中与分层爆裂 | 命中方向与有界并发保留；死亡爆裂消失取代为当前帧动画。 |
| v7 | 原正式死亡cue接自制实体爆裂声 | 用户认为怪，当前停用；保留原件与技术验证，不宣称听感通过。 |
| v8首候选 | 真正绘制受伤／死亡帧并留尸 | 独审发现材质、比例、轮廓回接跳变，完整保留v8-first-review。 |
| v8-r2当前 | 实际alpha主体、整套固定比例、脚锚／Atlas局部UV／材料映射；补逐帧脚底扫查 | Underworld具体色材反例明显改善；结构连续性仍REWORK，正式恢复仍有失败。 |

原始提交、媒体、失败和复审链见[任务交接](enemy_feedback_01.md)与[证据索引](evidence/enemy_feedback_01/README.md)。没有删除历史失败或把旧方向重写成当前要求。

## 所有改动的盘点边界

上述基线至620c共 **1046文件：1043新增、3修改、0删除**。其中978份是证据（含原日志、影片、截图导入配置、bundle与旧失败），并非1046份运行代码。

| 路径组 | 文件数 | 内容 |
|---|---:|---|
| scripts | 17 | 3既有脚本修改，7任务叶／状态／shader及其UID新增。既有宿主UID未变。 |
| assets | 21 | 4帧图与导入／manifest／审计／来源，及历史死亡WAV和说明。 |
| tests | 14 | 7专项脚本与UID：native、formal、support、pixels、audio、旧粒子extent和v6 extent。历史extent结果不作为当前留尸签收。 |
| tools | 10 | 两代实际弹体录制驱动与UID、采集封装、声音候选／探针／生成器。 |
| docs/evidence | 978 | 全轮来源、音画、执行、失败、独审、回归证据。 |
| 其余docs | 6 | 任务、帧、艺术、参考、音频接口说明及原质量记录。 |

[逐文件清单](evidence/enemy_feedback_01/session_closeout/changes.tsv)逐项给出状态、路径、前后Git blob与终点字节数；只盘点至620c，不把本整理清单自包含进去。[机器摘要](evidence/enemy_feedback_01/session_closeout/inventory.json)给出基线、树和清单SHA。未因“无静态引用”删除旧helper、资产、Lab或证据。

## 当前验证与阻塞

精确运行源3003的既有独立结果：native458/0、support199/0、正常时钟audio278/0、GPU258/0；原四项Harness为actor-actions2872/0、underworld-damage-feedback317/0、underworld-formal96/0（两图）、forest-bible-integration54/0。[实际命令／退出码／独审](evidence/enemy_feedback_01/v8/review.md)及原日志保留。这是已有Development证据，本轮文档整理不重签fresh。

**整体仍REJECT／draft，不能合入验收：**

1. 正式存档strict formal **66/1，exit1**：隐藏的saved EnemyMotor未能恢复可见尸体；缺实际落尸位置与support-local保存合同。需总控Actor／Stage／save所有者分配接口，本线不另造存档。
2. Legacy飞怪等原live↔新hurt结构仍有跳变（实际影片876→877）；不能以bbox相同或像素不同声明丝滑。完整待机／运动／转向／攻击／恢复帧仍未制作。
3. 完整受影响Integration／Release、正式森林及ActionStudio所选消费者连续画面、用户手感和实体设备未完成。非单位缩放、斜坡／旋转支撑未验。
4. 两份Underworld逐字prompt未在压缩前落盘；重建brief不等于原话。精确模型版本／许可未知，C2PA块存在不补齐这些缺失。
5. 中央tasks为planned、任务卡为review，索引检查仍失败；保留总控文件只读边界，不写done或改断言来消红。
6. 本轮按真实PR基线执行 `check_quality_diff.py` 另报资产登记／消费者审计失败：任务资产旁的provenance文件尚未登记到原 `docs/quality/asset_records`，`frames_v8/`目录动态引用也需有限消费者适配审查。原始来源文件存在不等于质量系统已准入；修复应沿原登记／审查入口，不能跳过检查或编造缺失许可。

当前可看：[Underworld 14秒](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/620c40b3ca939cd9ba42d5cebcf9b97ccbbcef62/docs/evidence/enemy_feedback_01/v8/movies/after.mp4)、[Legacy 14秒](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/620c40b3ca939cd9ba42d5cebcf9b97ccbbcef62/docs/evidence/enemy_feedback_01/v8/movies/legacy.mp4)、[v7/v8同条件20秒](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/620c40b3ca939cd9ba42d5cebcf9b97ccbbcef62/docs/evidence/enemy_feedback_01/v8/movies/comparison.mp4)。都是实弹fixture，非自然路线或玩家验收。当前runtime bundle实际HEAD为3003；发布提交620c包含后续证据，二者身份分别记录。

## Skills回流与接续

[生产复盘与可复用制作卡](enemy_feedback_01_production_lessons.md)给出本会话证据、建议修改的skill位置、制作顺序及可复制的新怪物开工Prompt。本轮只交这份任务专属提案，**共享SKILL.md／中央模板未修改**；建议供总控整合，避免把局部帧数、音量或粒子量升级成所有怪物的固定参数。

下一轮优先统一每物种live与新动作的身体母版，关闭真实过渡反例；尸体保存由总控接口工作并行解决。之后按原 `tools/production_plan.py --stage integration --base e9ab0e0743466b8983e34cc7de17bab1abf9d53a --plan` 确认影响，实际执行原完整受影响检查与正式消费者，再做完整适用Release。计划不是执行；本轮不自动合main。

本次文档整理的实际检查与失败见[收口验证](evidence/enemy_feedback_01/session_closeout/README.md)；新增文件不改变原3003运行／独审证据身份，原动画卡保持REJECT。
