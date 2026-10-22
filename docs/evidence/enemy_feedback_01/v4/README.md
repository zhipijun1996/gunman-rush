# ENEMY-FEEDBACK-01 · v4 可读性与接触反馈样板

生产运行源 `8f0fd51`，扩展GPU测试源 `0d5b72c`（scripts/assets/resources生产树相同）。前版运行源 `bd8d130`。本轮依据[user-feedback](user-feedback.json)，继续animation-vfx / art-director / game-quality-gate，不改AI、数值、碰撞、奖励、Boss、音频、共享父类/母版或原PNG。不是全怪推广、完整新图集或整体美术完成。

## 已实现的限定改进

- 保留批准的0.12秒身体奶油闪。真实接受命中新增不超过0.075秒的三条渐尖接触碎芒；细屑8/12条、1wu宽，初速由40+4.5v改92+7v，扩大方向散开范围而不扩大方块或堆烟雾。只有既有正式Damageable/HealthState接受回执触发，不直接调用反馈伪造命中，不消费玩法RNG。
- 仅两个Underworld样板启用task-local材质重映射。源图原alpha和最暗轮廓保留；通过四邻alpha区分内部材料面，草甲偏鼠尾草/黄绿、飞行主体偏冷青石、现有暖色像素保旧铜亮面。原EnemyPresentation图集不启用新活体palette。不是原PNG重绘或共享材质母版替换；独立实际viewport消融验证有无提亮/alpha变化。
- 死体停止动作，渐去饱和；Underworld地面体从近站姿转到约152°翻侧，飞行体约95°侧倒。先从原身体精确交接，再沿原0.38秒转落/轻触地收势，opaque保留。两个链仍分别接共享组件，旧链沿已有authored death atlas及旧rest角。restore dead直接静态终态，不新flash/debris/death/drop。

《空洞骑士》研究及工程推导见[references](../../../enemy_feedback_01_references.md)，原作者可核实的是简洁造型与传统2D动画；网上二手毫秒/FreezeMoment反编译参数未核实、不照搬。顿帧/相机微冲击建议留给总控共享接口A/B；本轮不改全局time_scale或相机。音频继续搁置。

## 真实采证与边界

真实26秒影片保持前后同seed、输入、相机、分辨率和原伤害/AI，每物种13秒、真实Router→Shoot→弹体→HP2→1→0，末3.5秒尸体可见静止。使用显式Courier/简单地面fixture，因此不签正式平原画风黄金或手机性能。比较投影保原process-local event_id，实际frame/amount/HP/epoch/terminal与输入/shot另作因果比较。

首个v4采片由root过早启动，与尚未退出的editor import重叠。发现后主动SIGTERM中止该候选，原report/日志保留；它不是合格素材。等待import实际exit0后在独立新目录串行重采，不延长预算、改TTL或覆盖旧失败。

当前正式移动渡船尸体存档仍缺stable support/local rest pose，由总控持有Actor/Stage/save schema。本轮无权限/接口解决这个既有严格失败，保持失败断言；不伪造浮尸、不另存一套。完整Integration、正式视觉消费者与新绘走路/收腿/收翼/死亡帧、用户/真机仍未完成。新pose与palette只先改善局部读图，不能把整图翻转登记成真实动画帧。


## 当前媒体

[26秒新版](movies/after.mp4) · [26秒前后对照](movies/comparison.mp4)。四段对照为v3地面6秒→v4地面7秒→v3飞行6秒→v4飞行7秒，全部连续原始素材片段；原完整MovieMaker片也保留。原驱动沿v3schema复用，原片页脚的v3是采集器标签，不是候选源；交付片仅替换信息页脚为真实source/version，无游戏画面改绘、插帧、变速。具体ffmpeg命令及字节SHA见[movies/recipe](movies/recipe.json)。

[新版回执](movies/after-report.json)实际source_stable=true、1560玩法投影帧same=true、inputs/shots与接受事件因果投影same=true。原trace以gzip完整保留，文件名after.json.gz/before.json.gz，解压字节不变；没有声称进程局部Actor event_id原字符串相同。


## 验证结果与适用限度

独立冻结0d5专项：native378/0、support133/0、GPU112/0；严格formal62/1（移动渡船恢复仍失败）。原actor-actions / underworld-damage-feedback / underworld-formal / forest-bible-integration-tests四项fresh通过。未把较宽的旧formal检查通过覆盖本任务更严格的失败。planner因未注册叶组件范围保守列146项完整检查；这里只按用户先Development专项的要求执行上述受影响定向回归，完整Integration仍未执行，保持draft、不合main。

GPU同体同姿态render消融：charger源材质luma约0.130→0.351、diver约0.125→0.383，实际alpha改变0；活体饱和度约0.51，尸体约0.17。落稳接地gap都0px，暂停像素相同。ground lifeless最终采样约0.992而非精确1，air为1；这是非阻断终色残差，未宣称live-death与restore材料逐字节相同，也未为了这点更改冻结源或删除失败。

粒子另用相同driver在真实接受后2/6tick、实际age0.03333/0.1秒冻结，只切粒子visible，前后各80/0，源字节/接触点/HP/serial/相机/age相同。0.1秒实际可见半径charger6.305→13.673wu、diver6.811→14.283wu（约2.1倍）。第2tick含短接触核，所以不能把其倍率当纯散屑速度增长。全局physics tick因暂停render等待不同，未声称这组消融是全模拟轨迹一致；长片的1560玩法投影一致另有独立回执。[原始对照](extent/comparison.json)。

独审实际看片认为颜色、活死区分有可见改善；“更强命中/HK手感达标”仍不签：原cyan接触层在合成画面仍占主导，扩大细屑包络不等于最终触感满意。三条瞬时接触polygon最宽2.4wu，1wu仅指随后细屑，不夸称全部效果都是1wu。未来接触色/优先级需要总控协调正式projectile feedback消费者，本线不越界屏蔽正式接触或伪装其事件。

[可恢复运行源Git包](runtime-source.bundle)从远端既有5a04517到6de2d50，完整保留本地实际源8f0fd51/0d5b72c及前置历史；[manifest](runtime-source-manifest.json)记录大小SHA与生产子树等价。恢复：在有5a04517的克隆中 `git fetch <bundle路径> HEAD`，再 `git checkout --detach 8f0fd51`（采片源）或 `0d5b72c`（独立专项源）。CLI登录此前失效，发布继续用连接GitHub API校对每blob和完整tree、expected-head快进；发布commit元数据不是测试源，包可恢复真实提交。


## 打包期间新增的用户视频参考

用户分享https://b23.tv/BoR2aOJ，已定位BV1wtmiBoEss与Challacade原短片q9Kzd6f5mR0。可核实的简介列音效、闪色、粒子、击退、屏幕震动；完整视频/字幕当前访问失败，没有假称已看。新源冻结前的v4录像不冒充“已按该视频重做并验证”。[逐层对应、访问事实与总控相机接口请求](../../../enemy_feedback_01_references.md)记录了继续采用的方法，音效继续搁置，顿帧是否属于该片未核实。


文档守门：docs profile前7项fresh通过，在quality停止；早期v3→v4记录更新不完整产生的stale证据错误原件保留于docs-first。已经补新运行inventory与当前版本证据，最终单卡errors=[]，仍总体REJECT。中央check_quality继续因总控持有的tasks planned/本卡review不同步而失败；不越界修改中央任务或把单卡一致当内容通过。root本轮check_docs/check_project/diff检查通过。
