# FOREGROUND-CONTINUITY-08

用户选择“固定前景物件＋离屏回收＋提前淡化＋稳定后恢复”。分支`art/formal-fine-depth`，运行源`6befe56b8802ac2472264b866deac1d7efdf649f`；原style-v5、素材、物理、地图生成和保存未修改。采用animation-vfx及visual-director，仅定向快速回归，不运行完整CI/Harness，不合main。

前景按世界格确定资产、尺寸、根点与风相位；已经进入视野的实例只在完整框+4wu离屏后回收。保护不释放身份或抢换另一株。动态危险距露出区域64wu以内提前淡出（0.18秒），安全连续0.3秒后0.7秒恢复；取消原0.65可见门槛。草叶的静态边界与HUD保留即时局部shader遮罩；长枝条对全部保护范围整枝提前淡化，避免被剪成悬叶。所有物件保留即时局部shader遮罩，严格框内alpha零、外24wu羽化，overflow仍全隐藏。此策略取代旧05/06整株bbox保护，功能保护区域未删。

## 验证边界

- `continuity.json`：真实Home消费者506采样、23固定身份、镜头往返、回收、重复refresh与暂停，失败0。camera是诊断移动，不冒充真人路线。
- `pixel_audit.json`：真实GPU with/without前景差分，1262非零前景采样，387080严格保护像素内差0。动态碰撞guard是测试刺激，不是敌战斗证明。
- `recovery_audit.json`：guard加入时草alpha0.9，移除后0.183秒仍0，0.85秒为0.72857，实际延迟/渐入成立。
- `capture.json`：Home两窗、平原两图×两Seed共六定位窗，失败0；选图附本目录，其余build/foreground_continuity_08/captures。不是全地图/全部Seed/全部敌人动态覆盖。
- `first_failure.json`保留首版失败：永久UI使整草消失及回收取整误差，修后新跑通过，未追认旧红。

## 恢复

需要真实显示GPU（此环境Xorg :102 / llvmpipe），不是headless画面。`bash tools/godot.sh --path . --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 --script tools/verify_foreground_continuity.gd`；六窗入口`tools/capture_foreground_continuity.gd`。电影同真实MovieWriter先60帧smoke，再`--write-movie build/foreground_continuity_08/movie/raw.avi --script tools/capture_foreground_continuity_movie.gd -- --trace=res://build/foreground_continuity_08/movie_trace.json`。12秒真实家园Router移动/跳跃，12秒平原图一镜头往返；后者不是正常通关路线，无同条件旧版电影。电影录制全程没有PNG读屏。

用户美术认可、全部预警/弹体/机关组合、真人全程、移动设备性能与完整CI保持未验证。无新图像生成、原素材许可/生成记录保持；新增成本为实现与软件GPU采证，模型价格/用量not_exposed。

中间源632fce6的平原图一右枝出现横切/脱枝叶，独审REWORK后按整枝提前避让修复。原图见`branch_cut_632fce6.png`；新源重新采图/录片，不复用旧片。

交付：[24秒公开实机视频/截图](https://zhipijun1996.github.io/gunman-rush-previews/reviews/FOREGROUND-CONTINUITY-08/6befe56/)，Pages39887917620 success，host f71d956、media f52982c。公开MP4及两图完整字节与SHA已核，Chromium实际播放>1秒、1280×720/24.233秒、两图加载、errors0。只运行托管部署工作流，不是完整游戏CI；不是可玩Web更新。
