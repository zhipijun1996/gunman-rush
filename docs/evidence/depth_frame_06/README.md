# DEPTH-FRAME-06 中景地标与人物前方氛围

响应用户“中景太少、不够精美、风车钟塔要更多更大”和“人物前方氛围层没有加”。运行源 `4a41fd729ed06e6806826bf97ded3be5c9c817ed`，基线 `059618d41f43814e431cb8a7632d06083336e12e`。仍为快速视觉实验，不跑完整CI/Harness，不合main，不代签美术或真机认可。

中景改用1672×941细源：三座风车、主钟楼与小铃塔、成组石台村落，单层宽度从1.8视口改1.2以保留更大的塔体；冷灰空气透视保留42%去饱和源材质。位置偏移让主塔离开人物轮廓与家园工坊。旧原图和三层独立视差继续保留。

前景直接取上一轮1619×972原母版的高细节Atlas裁块，未放大旧低清PNG。下角170–184wu草与侧缘224–352wu枝，1wu采样、1.15/1.12视差、不到2wu风幅；完整图框+3wu避让人物/枪口/瞄线/弹体/落点边缘/机关奖励/HUD，警告与保护溢出隐藏。世界格稀疏候选，最多2草1枝，保留开阔镜头。

## 实际检查

- 正式Home、两张Plains×三个Seed、高/低/分岔/铃机关和共享Forest，共30张1280×720定位静图，退出0，无脚本/shader/泄漏错误；不是路线通关。实际相机/Manifest/保护框在 [capture.json](capture.json)。
- 21/30镜头有可见前景，透明度至少0.65；Home与Plains图一正常出生镜头均0.9。完整前景矩形+3wu与当帧真实保护区交叠0。其余9镜头保留无前景留白或安全避让，不以数量签美术。[采样审计](foreground_capture_audit.json)。
- 原景层检查450项、0失败，3种视口×5个横纵镜头覆盖/不同层速/不镜像/支撑/keepout。只跑相关检查，未改断言或预算。[日志](scenery-check.log)。
- before使用上一轮实际PNG，对应同Home相机与同Plains Seed/出生位置；启动时刻、角色姿态有差异，无同输入before电影。
- 真实MovieWriter短片和公开链接以交付收据为准。前12秒Home真实Router走跳，之后两张Plains各6秒连续相机诊断，角色仍在出生区，含加载/清理帧，不能称完整游玩。

## 失败与来源

本轮AI图像两次调用，模型/计费未暴露。第一版桥顶与可玩平台齐平，独立审查指出假道路；保留原图，在第二次编辑中降低并打断桥跨。首轮新前景Home草可见、Plains侧枝候选为0（非全被保护剔除）；缩小世界格间距增加候选机会，未减少完整遮挡保护。X99旧显示服务已失效，一次GPU启动失败；X100重试成功。所有失败日志在build/scratch工作产物保留，不追认为通过。

原图、两轮Prompt、来源/hash/未知许可在 `assets/underworld_plains/backgrounds/depth_frame_06/`，机器资产记录与全局manifest登记实际采用r2。旧来源许可、原Bible、style-v5原字节与物理/RNG/保存/资源保持不动。

## 恢复与限制

`bash tools/godot.sh --path .` 进入正式游戏。静图用 `--script tools/capture_depth_frame.gd -- --output=res://build/depth_frame_06/<fresh>`，可加`--quick`采三张；电影用 `--fixed-fps 60 --write-movie <file.avi> --script tools/capture_depth_frame_movie.gd -- --trace=res://build/depth_frame_06/movie_trace.json`。需真实GPU显示，headless不能代替影片。

独立局部审查见 [independent_review](independent_review.md)。前景在冲突/候选可见阈值处可能显隐，尚未签全动态遮挡与连续性；中景采用固定画中风车，旋转仍由原有近背景风车提供，未声称新画中风车逐个独立转动。完整影片艺术/音轨、移动设备性能、全路线与玩家认可仍未验证。上一轮公开可玩包受900MiB托管上限和新仓库权限拒绝阻挡，本轮交付小型视频/实机评审页，不用旧可玩链接冒充更新。

## 本轮交付

[公开评审页](https://zhipijun1996.github.io/gunman-rush-previews/reviews/DEPTH-FRAME-06/4a41fd7/) · [真实MP4](https://zhipijun1996.github.io/gunman-rush-previews/reviews/DEPTH-FRAME-06/4a41fd7/depth_frame_06.mp4)。MP4为24.366667秒、1280×720、60fps、48k立体声，25728614字节。宿主提交f3a7a89，Pages运行39877020268；Pages实际success，公开完整MP4、build-info与三张精选PNG字节匹配本地；Chromium实际播放至1.23秒，1280×720/24.366667秒，全部图加载，errors=[]。见[公开字节](public-review.json)与[实际浏览器](public-browser.json)，不代表全片/音轨或可玩Web验收。源码分支保留，不合main。

发布时远端有并行DEMO-UI更新，第一次push被拒，fetch/rebase保留其入口后再推送。旧本地宿主目录有135.25MiB已失去bundle的忽略PCK残留，导致一次容量检查失败；未删除任何历史或放宽900MiB预算，新建精确宿主SHA的干净worktree重建验证，实际Pages检查亦通过（精确重建901664180字节，约859.89MiB）。与真实生产运行失败分开记录。
