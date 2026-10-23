# PLAYER-PRESENTATION-01 · Motion candidate

[真实下落围巾样板：18.2秒](https://raw.githubusercontent.com/zhipijun1996/gunman-rush-previews/b8c3893457bab322c3d6c33e27e1a665ae00d6f1/site/deliveries/PLAYER-PRESENTATION-01/9c693787b201a655d9e8589d3bb1e1350ae64e29/a2f098627b60/after.mp4) · [真实跳落前后对照：20.5秒](https://raw.githubusercontent.com/zhipijun1996/gunman-rush-previews/f9f621c2ebfb64dd9e550a24e5f35a0e4e8d91ce/site/deliveries/PLAYER-PRESENTATION-01/5ff0c7aea4fcfb51713363b0b8ec4d4b5f56a22a/04c0b5c79427/comparison.mp4)。两个公网原件均匿名下载HTTP200并核完整长度/SHA，见media-public-v1/v2.json；下载不依赖Pages workflow。不是已发布Web Preview。

- v1源码 `9c693787b201a655d9e8589d3bb1e1350ae64e29`：两片各1092帧/18.2秒、1280×720/60fps、stereo48kHz。每片1080观察样本，16个玩法/枪口/镜头字段零差异，accepted事件相同；idle/fall六帧都实际绘制，旧run八帧只改变位移相位。保留首轮尘效偏弱和握持衔接REWORK。
- v2源码 `5ff0c7aea4fcfb51713363b0b8ec4d4b5f56a22a`：两片各615帧/10.25秒、同分辨率帧率音轨。每片600观察样本，16字段零差异、accepted事件一致、source_stable=true。只作两次起跳/落地局部取证；不替代v1长fall/返回观察。默认1080模式与原断言保留。落地尘效原尺寸可辨认获局部ACCEPT，起跳仍轻；不能签整个动作系统。
- [工程审查](engineering-review.json)、[首轮像素审查](pixel-review.json)、[VFX工程复审](vfx-review.json)、[VFX像素复审](vfx-pixel-review.json)保留各自版本。审查者未运行的测试不冒称本人运行；只看抽帧，不冒称全速播放或听音。
- motion-v1/v2-evidence.zip与各自index保留原始trace、完整capture source inventory/receipt、日志、失败、60+26张原尺寸视频抽帧、Web GUI截图与交付驱动。逐成员CRC/完整字节SHA读回验证。原MP4另有本目录两件精选原文件，未拼造动画。

## 独立可操作Preview

包 `build/player_presentation_01/motion-v1/player-motion-preview-c7a2529b3958.zip`（166886784字节），build `c7a2529b3958`，源码v2。解压运行 `python3 start_preview.py`；用原canonical reconstruct_pack逐块核验重建完整143MB PCK后开本地HTTP。ZIP实际解压并核每个文件，完整包在Chromium真实Space/A-D与鼠标开关/重启/Home返回完整游戏已验证。包是离线交付，不在此源码证据ZIP里；原build报告和包SHA/完整元数据在v2证据ZIP。

新公网Web没有上线：共享独立站两次实际被900MiB cap拒绝；临时Cloudflare API直连被网络拒绝。保留旧入口，不刷新原SHA、不拆包绕过站点守门、不用旧站冒充新版本。长久托管/容量由总控协调。

## 范围与失败

保护UnderworldPlayer脚本及三件body、DemoApp、正式场景、共享配置/Harness/通用音频均未改。任务dev子类只替换正常DemoApp正式平原组装后的视觉叶节点，其余真实玩家/地图/AI/资源/镜头照常；没有改位置/伤害/授予/装备。新源PNG不改像素，idle/fall限定采样，失败run两版停止扩产。

原Underworld专项607断言/583真实Motor帧/7状态通过；新任务trace1208检查、lifecycle19检查通过，限定其实际范围。Development计划仍因未知路径保守升级full，未全执行，完整Integration按用户要求由总控安排。docs本轮检查仍有稀疏缺历史evidence/archive链接失败，保留退出1与日志，不删旧链接或改签绿灯。

握持衔接、跑步原画、全武器/三外观/Home新动作、完整受伤恢复死亡、全速听看、玩家审美手感和实体设备未完成。详见[方法与取舍](../../../worklines/PLAYER-PRESENTATION-01/methodology-02.md)。
