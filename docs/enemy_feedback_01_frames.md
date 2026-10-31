# ENEMY-FEEDBACK-01 v8 帧样板

以最新用户“受击死亡帧动画／尸体”返工为依据。采用 animation-vfx、art-director、game-quality-gate；只修改表现，未新增敌人或实质行为，不扩大enemy-creator生产范围。

## 原有复用与样板

继续复用HealthState.changed的APPLIED实际负增量、event_id和epoch；不以接触或直接调用表现方法代替命中。EnemyPresentation与UnderworldEnemy分别安装同一个EnemyFeedback01状态、Frames图集适配、Particles和Remains叶；正式安装器仍替换旧表现，不能只改一个链。定义仅plains_charger／plains_diver，分别地面冲撞／空中俯冲，体型未改。

## 时间与锚点

非致死使用原feedback.tres.hurt_seconds=0.32秒，四个真实受伤姿态；新接受命中从第一帧重起，致死立即中断hurt。原命中闪色0.12秒保留，闪色只覆盖身体alpha，HP、预告和粒子各自绘制。原来行走／攻击动作继续走自己的时钟；本轮没有声称所有运动均有新帧。

死亡D1–D4共0.48秒，每帧0.12秒；空中未有真实支撑时最多保持D3并下落，落地才允许D4。四帧独立绘制四肢／翼片，不再旋转、压扁活图制造死亡。D4持续至stage卸载或health epoch变化。舞台兄弟节点避免父类死亡0.65秒隐藏整Motor后尸体一起消失；父类clock／alpha／visible只读。

Frames每套共用一个固定Vector2缩放，按H4主体映射到原live实际可见主体的宽高，保留旧flyer已有的显示长宽关系；两者都用alpha>16，禁止逐帧强行缩到同一尺寸。帧区整数裁取原PNG，不修改输出字节。独立region允许生成工具网格偏差，metadata不谎称均匀4×2；每行固定地脚基线／名义列中心，每帧真实alpha脚底另校正到实际支持面，不按透明AABB贴地。Legacy与Underworld各有自己的轮廓、素材和比例，不共用物种皮肤。新Underworld帧沿现有壳／青石／铜材料族提色；authored_palette仅新图启用，r-g归一化区分黄绿苔甲与真铜，固定族内输入亮度匹配原低值素材，Atlas局部UV控制顶部光。每次切帧与回原PNG显式刷新rect/分支，原live路径／Legacy／alpha／flash不变；尸体不叠lifeless压暗。

## 生命周期与限制

死档直接D4，零演出；Actor在health.initialize之后才应用saved transform，尸体首physics只重新核对位置／方向／支持，不重播。restore只在保存位置接触带内验证当前stage碰撞支持，缺少记录不能推断移动平台support-local落点；公开restore_support_verified/status，严格formal断言仍须失败，不能默默吸附远地面。保留v4原62/1失败和本轮实际复测。原存档schema、Actor／Stage／Definition归总控只读。当前stage真实动态支撑通过弱引用跟随，释放后坠落，void时间／距离有界。

暂停不推进动作；initialize立即清空hurt／粒子／尸体和去重，旧epoch／同terminal事件不重播；卸载disconnect并释放stage兄弟叶，不延长支撑物寿命。死亡／掉落仍由原Actor与DropService负责。

## 来源

实际原字节、逐帧region／anchor、alpha边界与完整源SHA见assets/enemy_feedback_01/frames_v8/{manifest.json,alpha_region_audit.json,*.provenance.json,*.generation-result.json}。使用image_gen生成／编辑，未使用Python修改图像；PIL仅统计透明像素和区域。Legacy两份逐字prompt已保留；Underworld两份逐字prompt在上下文压缩前未落盘，明确unavailable，只保留重建brief，不能冒充完整生成溯源。生成服务未暴露模型版本与许可字段，标unavailable，不补造。

原始图PNG/C2PA完整保存；实际GPU边缘、锚点连续性与风格须独立看正常速度影片，像素哈希不同不能签解剖动画或艺术认可。精确runtime／命令／失败／媒体见本轮证据入口，技术、独审、用户与真机分别记录。

## 总控接口请求与当前失败

首候选5ffd正式App66断言／2失败；当前3003独立复测66断言／1失败，仍为“official restored corpse stays visible despite hidden saved EnemyMotor”。旧v4的62／1移动渡船失败保留为历史；当前不能写成62／1或引用v5消失政策豁免。零重复演出、奖励与当前房间支撑是另外的验收项。

本线不写Actor／Stage／保存schema。请总控分配正式表现终点保存／恢复接口：需能由现有stage存档所有者保留实际落尸位置、朝向、可验证support稳定身份及其local接触关系，并在恢复组装完成后提供给表现；terminal本身足以选择静态D4，无须重播动画。字段／schema／迁移方案由总控持有，本线没有另建保存系统或新信号。缺接口时明确missing_saved_support，未通过的重载可见性仍阻塞合入。

当前支撑为中心竖直探针和当前frame可见最低像素，单位scale样板已测；宽轮廓斜坡、旋转支撑及非单位父缩放未验证，不宣称通用死体物理。

## 首候选独审后的有界修订

5ffd原片由独立审查确认93→94／876→877的色调与比例跳变，已保留为v8-first-review的REWORK历史。修订让H4实际alpha主体对齐原live可见宽高／脚锚／空中bob相位，不把整个透明cell宽度误当身体，也不把Legacy原来瘦长显示突然变成圆体。横向可见中心偏移只在draw bounds内补偿，尸体节点的原lethal x严格保持。

旧Legacy flyer原画延伸到碰撞脚底以下；致死开始时如像素已穿过地面，仅从实际Motor中心验证被身体跨过的真实地面并贴其top，不做远地面猜测。死亡切帧时将前一alpha脚底纳入下落扫查，防止肢体变化一步跨过薄支撑而漏接。死档则只验保存Actor碰撞脚底±2wu，不能用图片透明边界冒充接触，也不沿远ray寻找任意落尸点；正式丢失的fallen/support-local pose仍由总控负责。

原图、Def／AI／碰撞／伤害／奖励与父类clock均不改。首候选formal66/2历史保留，当前实际正式复测另记，不能凭比例／提色修订宣称保存已修复。

当前3003精确独审：native458/0、support199/0、audio278/0、GPU258/0，原4Harness fresh通过；formal66/1真实失败。材质反例有限关闭，结构回接仍REWORK，完整艺术／丝滑／用户与设备不签。
