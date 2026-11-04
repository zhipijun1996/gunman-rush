# plains_charger 制作与完成度卡

任务 `ENEMY-CONTINUITY-01`，内容版本 `charger-audit-v1`；基线 `45e98dbbf38d906dc5eae9686dc9ee5ee6a99acc`，分支 `docs/enemy-continuity-01`。使用[怪物完成标准](../../quality/enemy_completion_standard.md)和原[Enemy Design Sheet](../../templates/enemy_design.md)；[质量记录](../../quality/records/ENEMY-CONTINUITY-01.json)。

## 当前范围

本轮先建立统一标准，再核对现有冲锋怪「移动 → 受伤 → 恢复 → 死亡 → 留尸」。保持原AI、Definition、物理、HP、伤害、奖励、音频和美术字节。此卡区分当前源码、历史证据与本轮fresh实证；缺少完整出口证据的项目保留unverified，已看到的局部缺陷标failed，不回写旧ENEMY-FEEDBACK-01结论。

## 身份、机制与所有权

- stable_id：`plains_charger`；地区`windchime_plains`；地面冲锋职责。保留既有接近／预警／直线冲锋／恢复；玩家观察前摇、改变位置并利用恢复窗应对，是否有足够体验价值仍需正式遭遇及用户验证。
- 参数唯一运行来源：[plains_charger.tres](../../../resources/enemies/plains_charger.tres)及其Health／EnemyDefinition引用；本卡不建立另一套数值默认值。
- 地区方向：[风铃平原Bible](../../creative_direction/bibles/1-windchime_plains_region_bible_v2.md)，共享画风来源按[当前创作入口](../../creative_direction/README.md)；来源SHA见[源码盘点](../../evidence/enemy_completion_01/source_inventory.json)。
- 死亡政策：沿现有受伤／死亡帧合同留尸；不能改消失规避支撑或状态恢复问题。正式生成准入、并发压力与目标设备预算引用原设计，未在本卡凭空设值。
- 玩法由EnemyActor／EnemyAttackBehavior／EnemyMotor、HealthState／FrameDamagePolicy控制；受伤反馈只消费APPLIED负增量、当前epoch及唯一event_id。受伤视觉不能额外改变攻击中断、force或stagger。
- 死亡／掉落归原Actor及奖励服务；身体／受伤帧归表现宿主与EnemyFeedback01Frames；尸体归Stage兄弟节点EnemyFeedback01Remains；保存归PlainsRegionStage原actors容器的presentation_remains，不另造存档。

## 实际表现链和身体参考

| 范围 | 路径与事实 | 本轮验证边界 |
| --- | --- | --- |
| 正式Underworld链 | [安装器](../../../scripts/underworld_plains/underworld_actor_installer.gd)替换旧Presentation，装[UnderworldEnemy](../../../scripts/underworld_plains/underworld_enemy.gd)；继承PixelPlainsEnemy／WindchimeEnemyVisual的时钟和预警，实际身体由UnderworldEnemy绘制 | 父类存在动作代码不等于最终身体使用那些姿态；逐帧应观察实际feedback_body |
| 原始链 | [EnemyPresentation](../../../scripts/enemies/enemy_presentation.gd)，由patrol_drone场景组装后配置为该Definition | 单独用于保留链对照，不把它的画面冒称正式Underworld |
| 正式实例 | [PlainsRegionStage](../../../scripts/demo/plains_region_stage.gd)创建／恢复敌人，并经正式安装器；实际随机实例及镜头需新运行发现 | 源码接入存在，尚不等于本轮正式遭遇通过 |
| 现有录制fixture | [remains capture](../../../tools/enemy_feedback_01_remains_capture.gd)使用真实PlayerController／InputRouter、弹体、AI与伤害；初始站位、地形、镜头及关闭AirFocus显式设置 | 仅局部两物种／两链样板，不能代表自然路线、完整攻击组合、正常玩家资源或设备表现 |

Underworld活体参考为`assets/underworld_plains/actors/charger.png`；受伤／死亡为`assets/enemy_feedback_01/frames_v8/underworld_charger.png`及同目录manifest。原始链使用其原活体素材与`legacy_charger.png`，两链材质不混签。原PNG与导入不改。

Underworld以原实际可见body范围确定feedback_anchor和clip固定比例；地面接触参考Actor碰撞脚底，绘制脚底与碰撞脚底分列。新帧使用manifest整数regions／anchors与固定body_size／basis_px比例，不逐帧自动缩放。现有帧组为4受伤＋4死亡，仅是当前实现数量。

## 状态与转换盘点

| 转换／状态 | 当前实现事实 | 按标准还需观察的出口 |
| --- | --- | --- |
| 待机／移动／转向 | AI／Motor驱动位移，正式身体主要复用charger静态图、朝向镜像与状态Transform；父类的绘制步态不会自动成为最终新身体步态 | 正常速度是否表达步态／重量，转向锚点和身体身份是否连续；程序表现允许，但必须实看 |
| 预警 → 攻击 → 攻击恢复 | EnemyAttackBehavior按定义计时；Underworld用下沉／压伸和父类预警表达阶段 | 前摇、冲锋重心、收势与实际伤害窗口一致，非只出现警告符号；左右及墙／台边另验 |
| 移动／攻击 → 受伤 | EnemyFeedback01过滤接受回执，Frames.hurt_index选择H1–H4并切换实际body纹理 | 实弹命中时身体结构、亮色、脚锚连续；攻击中受伤遵守原机制，不从画面推断新stagger |
| 受伤 → 当前合法动作 | hurt_remaining到期后重新呈现原charger活体图与当前state；未见独立受伤退出clip | 重点查H4→live轮廓／材质／重心回接，不能以bbox匹配或代码分支存在判通过 |
| 连续命中／致死中断 | 真实Health回执重置hurt；terminal转由Stage兄弟remains持有演出，不受父Motor隐藏连带隐藏 | 重复事件不重播，致死不先闪回活体，死亡首帧和受伤末帧衔接正确 |
| 死亡 → 落地 → 留尸 | Frames／Remains选择D1–D4并按真实支撑停留；保存记录位置、支撑身份和局部接触锚 | 实际接地、薄台／移动台、支撑释放、暂停、回退／重载与零重复掉落／音画；长尾观察不能缺失 |

## E01–E12完成度

本轮已在锁定4.7.2实跑原native／support／corpse-save／snapshot，并采到当前Underworld链26.133秒原片；[连续性核对](../../evidence/enemy_completion_01/continuity_review.md)记录实际观察与未看范围。下表保留其他项的完整出口状态，不能用局部技术结果冲抵身体和退出缺陷。

以下为完整物种的出口状态；局部实跑范围另列，当前源存在性由source_inventory记录，历史证据不自动继承为本轮passed。

| 完成项 | 当前实现与缺口 | 状态／下一验证 |
| --- | --- | --- |
| E01 设计 | 既有冲锋定义与职责可追溯，当前整怪设计／反制未重新验收 | unverified：引用原设计并跑正式代表遭遇 |
| E02 行为 | 原AI／Motor／伤害链存在 | unverified：距离／视线／安全区／台边及实弹验证 |
| E03 身体 | live与hurt／death为不同源图，比例／材质适配已实现；当前视频94→95及143→144仍有背部结构／壳体／肢体突变 | failed：CHR-VIS-01；先统一同物种身体母版 |
| E04 动作覆盖 | 有live程序变形、4H＋4D；完整移动、转向、攻击、收势的可见表达需核 | unverified：逐状态看实际身体，不能把父类代码当已显示 |
| E05 连续性 | 当前Underworld两次受伤退出均可见结构突变，已看连续相邻视频帧，不伪称完整正常速度播放 | failed：CHR-VIS-01；新源重看相同进入／退出，再补其他转换 |
| E06 命中 | 接受事件驱动body／flash／particles | unverified：回执→可见首帧、拒绝／旧epoch与遮挡 |
| E07 终态 | 当前fixture实弹死亡后D1–D4／settled与210帧稳定可见长尾通过；原保存72／0、快照147／0 | unverified：完整终态出口还含正式场景与不同准入支撑；局部通过范围见核对报告 |
| E08 声音 | 沿当前共享音频来源；历史自制死亡声回退不代表当前声音认可 | unverified：实际音轨／试听与重复事件检查 |
| E09 遭遇 | 正式生成和保护条件有消费者 | unverified：当前正式场景与允许策略验证 |
| E10 生命周期 | 原暂停、epoch、清理和presentation_remains接口存在 | unverified：正式消费者／保存／重入专项 |
| E11 性能与来源 | 原资源／来源记录可查，设备预算未在本轮测量 | unverified：审计准入并按实际设备／场景测量 |
| E12 验收 | 历史独审为限定范围；当前源没有本轮独审、用户或设备认可 | unverified：当前版本独审及适用G5 |

最高连续已验G阶段：已有上述局部fresh技术证据，完整G1范围仍未关闭，G2身体／退出实证失败；不升签整阶段，不签怪物完成。实际charger片段没有attack状态，E04不能因已有预警和受伤帧而标通过。用户、设备、声音试听、独审及正式自然场景仍未验。原保存失败参考[旧会话总结](../../enemy_feedback_01_session_summary.md)，后续修复参考[尸体保存集成](../../evidence/enemy_corpse_save_integration/README.md)，保留各自源身份；历史Legacy飞怪876→877不直接当作当前冲锋怪缺陷。

## 采证顺序

先核项目锁定Godot版本与资源输入。原录制入口 `python3 tools/capture_enemy_feedback_01_remains.py --output build/enemy_continuity_01/underworld --variant after --chain underworld --expect-remains`；保留另一legacy链对照。该入口会涉及两个物种和显式fixture，范围必须如实记录。

影片记录各次真实接受事件对应的H进入／H退出、D进入／D结束及长尾；左右、连续命中、攻击中受伤、慢时和真实正式场景未由该片覆盖的项目另列。专项复用原formal／support／corpse-save测试，不改断言或预算。缺工具先记阻塞，不能用系统另一个Godot版本代签。
