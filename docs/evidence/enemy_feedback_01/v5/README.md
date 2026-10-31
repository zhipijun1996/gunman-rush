# ENEMY-FEEDBACK-01 · v5 爆裂后消失

当前修订运行源3c5338552b2f7ac275203c4bbf1003e29520a312，首候选167ff99保留为视觉拒绝。用户拒绝“把原图反过来”的死体，明确提出爆炸后消失，原话在[user-feedback](user-feedback.json)。因此这次替换死亡方案；不是补画死亡帧，也不是把旧失败伪称修好。旧v3/v4尸体及其62/1移动支撑保存失败完整保留历史。

沿animation-vfx / game-quality-gate，仍只plains_charger、plains_diver；原EnemyPresentation和UnderworldEnemy→PixelPlainsEnemy→WindchimeEnemyVisual分别接同一个任务死亡叶。没有新敌人/AI/判定/伤害/奖励/音效/Boss行为，不扩enemy-creator，不改父类死亡clock/visible或原PNG/共享材质。保留原受击闪色、v4亮材料和非致死细屑。

## 死亡时间轴与收束

只有现有正式Damageable事件被当前HealthState接受为唯一致死命中，才启动一次：

- 0–0.045秒：精确交接当前身体（旧链混合帧/shear也保留），短奶油闪。
- 随后：当前身体贴图切成最多10×8个有alpha的原纹理小片，单次向外冲量、微转/收小/退色，辅以极短断弧与16条细尾屑。空中对象散开略快，保本身皮肤，不贴另一套火球或红烟。
- 0.55秒前：可见碎片全部结束，叶进入spent并隐藏。没有翻转整图、尸体落地/平台追随、持续火焰、地形探测或新的碰撞/奖励。保持原时钟，暂停冻结，慢时用scaled delta。

restore dead只恢复spent/inactive/hidden，没有爆裂/命中闪/碎屑/掉落；restore alive立即清旧粒子。epoch/serial/idempotence门继续复用；host卸载清监听、贴图引用和stage sibling。保留Remains类名/绑定接口以复用同一叶和两条链，内部不再维护持久尸体逻辑。

## 验证归属与历史边界

四专项针对新用户合同：正式实弹→接受→爆裂→有界消失；拒绝/重复/旧epoch不得触发；暂停/慢时/restore/unload/掉落不重播。早期任务原素材/正式源SHA仍守门。旧“长时可见尸体”的断言换成新“结束无残体/死档无演出”是有明确用户依据的合同替换，旧反例继续留在v4，不说现有support-local save/schema已被修复。

首轮GPU162项2失败：采样crop混入了已接受弹体的正式cyan接触层，暂停时该层合法冻结，但任务死亡叶已经spent/hidden。修订只让测试viewport按death leaf visibility bit采集，再恢复所有mask；不清globalFX、不降低early>20/碎解>0/取消与结束=0门槛。首失败PNG/log/回执保留。新层隔离真实GPU复验162/0。首headless粒子采样误用了需要frame_post_draw的GPU驱动，被主动终止；此运行只作启动错误记录，不拿作完成证据。

所有影片由真实Router/Shoot/弹体/HP驱动。显式Courier/简单地面fixture，不是正式平原美术黄金或自然路线；音轨保留原音效，未新增声音。新运动帧、整体美术/手感、全受影响Integration、用户/真机仍未完成。


## 第一候选的真实视觉拒绝与返工

167ff99完整26秒片确实完成6次HP提交/2次死亡/末210帧消失，且与v4的1560玩法帧及输入/事件投影相等；但作者与独审实际看v188/v972发现白金矩形切片与翅面网格缝，判视觉REWORK。原片/trace/report存rejected-rectangle。返工保80片预算及同一事件/时钟/结束合同，把quad改成带原纹理UV的渐尖不规则五边片，片初始尺寸约72%，仅死亡叶的闪色在0.08秒内退回本体材质；非致死批准flash参数/shader不变。新源另冻、另采、另验，不覆盖首片。


## 当前真实短片与恢复

[14秒新版](movies/after.mp4) · [20秒前后对照](movies/comparison.mp4)，均为原MovieMaker连续片段，保真实音轨。原26秒全片在movies/after-raw.mp4；每物种真实三弹HP2→1→0，完整末210帧/3.5秒确认无本任务death叶残体，同时接受后前20帧确实观察到死亡叶，防止“从来没演出”冒充清理成功。

前版直接复用v4归档的8f0原片，输入/镜头/Seed/分辨率/伤害/AI均保持。新版report实际source_stable=true，1560玩法投影及输入/shot/接受事件因果投影同前版。观察器仅新增消失断言/记录和信息页脚，不改驱动输入；不声称两个观察器字节相同。新trace完整gzip、原片/剪辑区间/ffmpeg/SHA见movies；14秒为每物种前7秒，20秒对照为各物种旧5秒→新5秒，没有插帧/变速/静图动画。

[运行源Git包](runtime-source.bundle)仅依赖实际公开v4提交19ccbb24a6e57d71cfbe6ddb038b858683414e08，保167首候选和3c修订的真实提交；[manifest](runtime-source-manifest.json)含SHA/大小/树。公共Git只读fetch可用，先保存本地v4元数据backup分支，再在同一完整tree下软对齐published parent，未覆盖工作文件或强推。恢复：具有19ccbb的克隆 `git fetch <bundle路径> HEAD`，再 `git checkout --detach 3c5338552b2f7ac275203c4bbf1003e29520a312`。发布GitHub API生成的commit元数据可能不同，始终比对blob及最终tree，不把发布SHA说成采片源。

## 最终实测与保留范围

独立复跑：native370/0、support141/0、实际GPU162/0、原Atlas实际GPU32/0、默认App62/0，均exit0。原始四项受影响Harness亦新跑通过：actor-actions2872/0、underworld-damage-feedback317/0、underworld-formal96/0、forest-bible-integration54/0。独审读取全部日志并检查连续邻帧，未声称完整常速播放、听感评审或真机性能。selected Harness报告与日志在affected；其余逐项原始日志/PNG在independent。

采集器沿用旧v3-remains-review schema名称；它表示复用的采集格式，当前真实运行源是3c53385，expect_disappear=true，并非重新标记旧片。14秒/20秒新片均在recipe记录实际区间与完整哈希。首矩形候选和首GPU归属失败均留档，不覆盖为成功。

质量卡整体仍REJECT：完整146项Integration、正式视觉消费者、完整运动帧、整体美术与用户/设备验收仍欠缺。中央任务索引planned/review同步由总控持有，本任务不越权修改。当前只交付可复核的新死亡候选，保持草稿，不合主线。

最终docs Harness前7项通过，第8项quality因中央Task index/record mismatch停止，余项未跑；日志与报告见docs-check。单卡quality一致性errors=[]，但整体仍REJECT。中央索引由总控持有，未越权同步或把docs profile称为全通过。
