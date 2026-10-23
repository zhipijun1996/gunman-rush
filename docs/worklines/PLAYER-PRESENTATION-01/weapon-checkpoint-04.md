# 多武器声音与弹体细节检查点

用户追加：多种武器的音效和子弹特效也优化细节。承接已验证移动／重落地候选，采用weapon-creator、animation-vfx、game-quality-gate与独立gameplay-reviewer。本轮仅任务消费者，所有原Gameplay、Definition、Motor、物理、伤害、资源、授予、共享通用音频、正式场景和4件受保护母版保持只读；main仍e9ab0e0，父候选616fe0b已含前两次交付。中央任务／Integration归总控。

实际15装备对应9Mode：PULSE、MACHINE、LASER、SHURIKEN、FAN、BOOMERANG、BOMB、MINE、SINGULARITY；六Lv3保留对应Lv2普攻，另有技能。不是15套独立弹道。PlayerProjectile用于枪弹／散华飞刃，WeaponEntity用于回旋与雷，Runtime直接画持续激光、奇点和爆炸。Underworld原绘制已区分bell／blade，不能声称所有弹体同形；普通friendly bullet共用cream/brass头。实际Home身体为Underworld，但其弹体可能走原非pixel fallback；正式Plains的DemoApp先装PixelPlainsProjectile，须分别恢复／验证。

发现声音缺口：PlayerFeedback的shot统一用原laser2，通用impact用木击；Runtime起手、激光tick、附着／接回／爆炸复用jump／focus／confirm／impact。GameAudio.cue会丢失origin，按cue-id＋LIFO计数屏蔽的方案被独审否决：同步回调可先发同名声音，吞错并留下原cue。该方案未实施，不能用get_stack或全局静音绕过。

当前消费接口全部复用：ShootAbility.shot_fired每颗实体一次、projectile_impacted供OFF原方法委派；每颗真实PlayerProjectile.impacted提供接触点／方向（含墙，不能说都是提交伤害），presentation提供视觉叶；Runtime.phase_changed／blast_fired／entity_transition及只读实际beam segment／entities支持小幅附加表现。Boss特殊接触原本不发通用impacted，保持原分支，未制造假命中。consumer直接读已有runtime／实体数组，避免带创建或清理副作用的getter。

声音按epoch／packet／physics tick／cue合并同一齐射，保留三连／storm后续tick的节奏；同一原12voice池，保护受伤／死亡／警示，低优先脚步可让位。6种声层×3离线细微变体，共18 WAV，来源／完整SHA／峰值与合成公式可重建；不使用全局RNG。原Runtime phase／爆炸／catch等声音仍在，新增blast／接回材料声是有意的附加层；beam仅0.8秒有限声段，非覆盖任意时长的loop。全套来源明确的新音频路由需总控协调，未声称已解决。

弹体细节保留真实7点历史、原飞刃图和转速，枪弹按类型调整紧凑轮廓／明芯、尾迹渐细；接触短碎光、爆炸薄断环、真实激光接触端微光与雷附着小标。无满屏闪白／新屏幕震动／时间缩放／改变半径或弹道。原Underworld muzzle/impact保留，不重复造伪伤害；未以此签所有武器完整演出。参数入口weapon_feel_v1.tres，尾迹／强度／声层衰减／生命周期／上限有限校验，非法或未绑定消费者保持关闭。

可证伪目标：真实原Home正常出生／原几何，加明确TRAINING静止靶（新fixture1000HP初始化，不改玩家HP／资源、不发奖励）；正常Router走到距离、各Mode开火／情境，真实扫掠／伤害／反冲。ON/OFF相同采样比较包含实际弹体、实体、目标HP、精力、共鸣、枪口、镜头、冷却的28字段零差异；FAN同刻三／九刃只有一条release声，storm各轮保持；切回原Home／正式Plains原pixel叶恢复，暂停／清理／取消空charge不发炮声。另15normal＋6skill通过真实命中攒共鸣，不注入余额；该训练样板不是正式成长或战斗AI证据。

先冻源采真实带声电影，再实际导出包／浏览器；用户听感、审美、连续全速体验与实体设备保持未验。既有公共Web容量和Release资产上传阻塞保留，不用旧URL冒充新包。新增共享来源接口拟议：带来源actor／weapon_epoch／packet／event及明确触发kind的accepted audio事件，现有旧消费者必须保留；当前只写影响分析，不改通用音频或自刷style SHA。
