# BELLSTRIDER-REWORK-01 独立审查02

**有限源码／其他作者的原生路由证据接受，G4及当前视觉黄金仍未通过。** 审查者没有编写生产代码，也没有编写本次审查的weapon_routes；没有运行Godot。自己的damage_policy测试及其86/0不在独立通过范围。

审查绑定当前开发工作树的18个实际源SHA，未称Git clean或完整CI。独立只读核对29项／0失败；这些数字是收据与源检查，不是新增原生运行。详见 `/tmp/bellstrider-review-02.json`、实际脚本 `/tmp/review_bellstrider_02.py`、日志 `/tmp/bellstrider-review-02-pure.log`。

## 实际画面判断

已实际查看capture01的probe-04／probe-15，以及用ffmpeg从同一真实MP4提取的7／11／19秒完整画面。主铃在车壳上方形成最亮、清楚的单一视觉中心；空钟架留出轮廓，旧中央铃芯字样／圈标已移除。轮、车架、钟架和铃在警告／移动／恢复截图中呈现不同姿态，未见怪物路径线。画面中的青色射线属于玩家瞄准，不能误删成怪物辅助线。

像素粒度整体接近现有玩家与场景，nearest和原PNG局部取样保持硬边；但新车壳大块平涂更像哑光硬板，铃与旧场景则有更密的旧铜／纹理。需要在当前完整黄金中确认车壳的厚度、材质层次与局部亮面；不能凭PNG未改或采样代码判艺术通过。这里不要求提高整车亮度，主铃仍应最醒目。

capture01本身是失败样本：70.766667秒、4246帧、1280×720／60fps，含原引擎音轨，但玩家死亡后driver访问已释放encounter，未生成trace。不能据该片签两枪／贪第三枪、阶段二、死亡残骸或喷币拾取完整性。其HUD拥挤是已知旧画面，后续HUD源码修正尚需当前实机图验证，不把旧问题重复认定为当前冻结失败。

两份完整外部输入清单各32025项及Git元数据实际完全相等；旧报告source_stable=false和“源变化”文字不能证明真实源漂移，因为driver独立trace缺失。当前wrapper已把external_source_stable与driver_source_guard分开。旧失败及错误诊断原文仍应保留。当前Presentation、App与capture01字节不同，影片不追签为最新源。

## 主铃判定与入场锚点

实际core Area和绘制都消费同一Encounter rig，canonical只统一FrameDamagePolicy授权身份，真实目标／点仍是空间core；装甲不具effect资格且保留物理阻挡。ItemActiveEffects独立物理碰撞、G14 primary分配、P12资格和同伴锁定已有相应筛选，未把甲上命中自动搬到铃上。

发现的旧Arrival偏移风险成立：滚轮入场subject.position横移最高18wu，skip_intro立即开放伤害后仅靠600wu/s渐回零，60Hz下一帧理论仍有8wu偏差。当前BellstriderPresentation已独立接objective_changed，非intro同步position=ZERO；该Bell限定源码修正接受，未更改其他Boss入场。仍需skip／暂停恢复／首个合法命中tick的实际visible-world bell transform＝Area world transform原生证明，不能只比两个Motor-local rig值。

## 新weapon_routes 88/0的实际边界

观察到原log `native-weapon-routes-02.log` 88/0且无脚本／泄漏错误。实际JSON含：主铃钩索40→39；装甲钩索40→40；真实炸弹一次AoE40→38；已生成且飞行的WeaponEntity回旋40→38。测试通过原App、真实输入和原sink，观察器保留原返回值，未写HP／Boss mode／clock／准入表。伪造钩索字段在真实hook_pull中逐项被拒，重复事件与未发packet也有拒绝反例。

钩索保护样本明确使用额外物理BossProjectile和无关接触夹具，保留真实政策与伤害提交；它没有冒称自然Boss弹体，也没有冒称当前hook姿态真的与未保护body重叠。源码将保护限制到canonical所属身体，不保护弹体及无关来源。空中定位夹具的第一tick可能仍有旧_was_grounded缓存，因此该证据只签伤害路由，不能签自然空中资源／反冲预算。全15武器、Lv3与完整打法尚未覆盖。

## 终态恢复与音频生命期

观察原rewards37/0：Stage在载入terminal Health之前调用prepare_terminal_restore设置dead／禁碰撞；_on_defeat已有dead早退，完整恢复死亡年龄／impact／jam／finished标志。原测试保存的是已进入死亡过程的非默认位置和精确rig，验证无新的death/jam/impact/final事件，耐久金币与领取锁不重复。接受该有限源码及37项原生证据，不扩大为所有旧保存／完整自然领奖通过。

GameAudio去掉“voice.playing为false就跳过owner检查”，修复暂停期间流仍占用但owner已退出的清理。原pool85/0及生命周期快照确认这一范围；未试听，不签听感，也不把场地封门／旧入场boss_impact计数当重复弱点共鸣。

当前仍需冻结源完整自然战斗／当前GUI：两枪与成功／失败贪第三枪、真实完整组躲避、半血回冲、临界墙角与残存危险、死亡落位及完整喷币领取。旧失败片保留，G1–G5、艺术、听感、真机与用户认可均未代签。
