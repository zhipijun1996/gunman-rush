# 起跳、落地声音与高落差反馈候选

用户追加同意起跳／落地音效，并要求从很高处落下的震动和人物后摇。沿用player-creator、animation-vfx、game-quality-gate及既有质量卡。本轮是任务专属Development候选，不改正式共享母版，不签全动作／全武器／三外观完成。

实际消费者为原Home正常出生的PlayerMotor、Controller、Router、Courier枪口锚点；只用任务Underworld子类替换视觉叶。独立入口 `scenes/dev/player_presentation_01/landing_feel.tscn`，保留原平原入口和完整游戏。HOME DROP按钮重新打开当前候选Home；HOME/FULL GAME恢复原Home身体／原jump和land消费者。三种角色的选择仍由原Home提供；本次没有制作三套新身体资源，也未逐个外观验收。

只观察accepted jump／land、实际apex→contact落差和落地前速度。默认落差至少180wu且速度至少最大普通下落速度90%才重落地，两个条件都满足；普通短跳／零airborne／返段不触发。真实Home两层露台至安全草地约192.0556wu、800wu/s作为可证伪样板；不是任意高度摔落或新摔伤规则。

重落地反馈：最多3屏幕像素、0.14秒衰减震动；0.24秒复用原land两帧的视觉缓冲。屏幕采样位于CanvasLayer1，只偏移世界画面，HUD不晃；Camera2D、canvas变换和鼠标世界方向不变。视觉缓冲不写Controller状态、不延迟输入、不锁移动；真实移动／合法跳跃／受伤／死亡／返段／关闭候选会取消。参数在任务profile中有有限范围和NaN/INF拒绝。

音效从现有Kenney CC0原素材制作9个短WAV（起跳0.17秒、轻落地0.21秒、重落地0.25秒，各3个离线微变化），具体来源、SHA和处理可重建。只做当前草地／衣料／软冲击的层次；没有声称材质路由或脚步逐帧重做。原step／shot／hurt／death等保留，同一原12声部，不另起播放器池；池满可抢占脚步或低优先运动声，保护枪声／受伤／死亡／警示，无法接纳则记丢弃。原jump／land在此消费者ON时解绑避免双播，OFF委派原方法；每次accepted land同步复位原表现落速累计器。

测试须在未改Home几何／无位置注入／无HP、资源、能力授予注入下走到露台，真实跳上两层、两次drop-through安全落下，并在第二次后摇中立即合法跳跃。ON/OFF同条件比较14字段：sample、tick、position、velocity、normal、recoil、motion_steps、hp、stamina、muzzle、aim、canvas、camera_offset、body；heavy布尔和render_body属于有意的表现差异。仍须真实带声电影、实际导出包浏览器和独立审查；听感／用户审美／手感／真机保持未验证。完整受影响Integration与正式绑定由总控安排。
