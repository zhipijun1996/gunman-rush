# 用户七项反馈：V2 契约与共享影响

从候选0509837继续；main共同基线仍e9ab0e0。用户新增要求：命中怪／打空听觉区分、参考开源游戏、回旋镖高速返回可见刃体、真实爆炸音、磁雷超时自爆和加速滴声、离子激光、黑洞奇点、枪／机枪有相应枪声。旧v1声音与录像保留；新入口 `weapon_feel_v2.tscn`，不是改签旧候选。

本次唯一玩法变更为用户明确追加的磁雷超时自爆：Lv2和Lv3分支普攻／技能共用 actual Definition 中6秒 mine_fuse_seconds，从真实实体生成起计（含飞行和附着），原4秒无声消失寿命一并延至6秒。到期调用原 explode，不复制伤害／半径／反冲算法；提前遥爆、暂停、宿主丢失、清理和epoch失效维持原退出。其余 Motor、输入、物理、资源、授予、伤害计算保持不变。旧style受保护4件继续只读，不自刷SHA。

为解决上一轮来源丢失问题，最小共享接口增量由本轮提交总控复核，正式采用仍待协调：

- PlayerController.weapon_damage_committed：仅既有 successful on_committed 回调经过原session／epoch／alive守门后，在原结算全部完成末尾附加信号。V2音效订阅此事实，打空／撞墙／拒绝／护甲未扣血不冒充命中。
- PlayerProjectile.terrain_impacted：既有物理contact中 receiver==null 的额外通知；原impacted和Boss分支保留。墙面声和敌人伤害声独立，击空仅有开火声，不凭延时猜命中。
- WeaponActionRuntime.audio_override：仅该producer可选Callable返回handled；无handler／OFF精确回落原GameAudio.cue。没有全局cue名称、计数或堆栈过滤。原状态转移／爆炸／catch调用处不变。
- Runtime.presentation 可选CanvasItem叶：仅V2可见时替换对应draw（beam／singularity／blast／return）；blink／链电弧／fan／charge保留旧绘制。return_flash标识return_blade，OFF仍原整线及.3秒；ON用实际已扫掠段绘制.14秒飞回刃体。真实手动回程仍当帧世界扫掠、伤害、接刃，没有延迟玩法或凭空删刃。
- 旧任务Preview仅新增实际V2子类所用两处工厂方法，原v1入口／默认声音／profile保持。V2卸载恢复旧信号、Runtime叶与音频hook，声音仍在原12voice池、最多8新武器声保留4格给旧受伤／警示／UI。

Freedoom固定源BSD-3-Clause实际游戏PCM，完整license／credits、原WAV压缩包和处理／输出SHA保留；42音频有独立PRIMARY登记。不是声称实录枪械或听感已验。枪和机枪为短攻击，hit为真正伤害叠层，wall为固体接触，blast为爆炸主体；ion和blackhole为不同持续声，采用WAV显式loop并由accepted phase停止；磁雷读取真实age／fuse调度由慢到快的有限beep，不决定爆炸。

可证伪目标：同源V2 ON/OFF真实Home九Mode样板及15装备／6真实攒资源技能的28字段和accepted事件一致（两边都有新6秒引信）；命中怪仅成功伤害播放hit，打空／墙／拒绝无hit；6秒时仅一次爆炸，提前遥爆／宿主消失／暂停／退出反例成立；持续循环在暂停／结束／切装／卸载停住且无幽灵音。真实GPU短片必须看到回旋刃体高速回程、离子束粒子沿真实止点、黑洞核／内吸和实际爆炸，不以代码存在签像素。完整正式受影响Integration由总控组织；旧run／握持及全动作M1、用户听感／审美／手感、真机保持未验。
