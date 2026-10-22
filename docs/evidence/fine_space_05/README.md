# FINE-SPACE-05 正式细粒度与空间表现

用户已明确选择细粒度并要求以后统一。本轮将 native32px/32wu 地形、1wu世界采样与暖光接入正式 HomeScene 和 DemoApp 两张平原地图；修正房屋/树根的可见足点，保留逻辑槽位和碰撞。森林共享材质/承载/角色/荆棘消费者同步，区域树皮身份保持。历史16px资源、v4和两份原Bible不变。

采用 art-director、visual-director、scene-composer、animation-vfx、project-integration。Fast Iteration→正式消费者复核；用户指定不跑各种CI，因此没有完整CI/Harness/Release或全路线完成声明。

三张独立环境图、不同明度/饱和度/轮廓与视差，晨空暖地平线、冷山丘陵地标、近处植被；同向横向重复、整数共享拼接步长和连续有界纵漂，底部像素延展。新独立风车转子/旗，云、草尖、铃轻风；暖点光最多8盏。前景最多2草1枝，世界Seed稀疏候选，屏外挂点，整图+风幅保护人物/预告/弹体/机关/奖励/平台边缘/HUD，冲突即隐藏。

## 实际验证与范围

- `test_underworld_terrain.gd --gpu`：5类边界、239910项检查，0失败；GPU分割前后一致且outside_spill=0。
- `test_underworld_scenery.gd`：3种视口×5种横纵镜头，450项，0失败；保留覆盖/支撑/keepout，只改符合新同向云重复的旧mirror断言。
- `test_underworld_identity_population.gd`：20个正式地图案例，21572项，0失败；实际Sprite变换/source foot与两端支撑射线。
- `test_underworld_formal.gd`：2张正式图，96项，0失败。首轮全局transform snap导致商人x偏0.458wu，已撤回；Shader只调整画面顶点，交互坐标不改，原严格断言保留。
- 实机截图：2图×3Seed，出生/高/低/分岔/机关及家园3镜头和森林，共30张。定位诊断静图，不是路线通关；角色诊断位置可能与NPC重合。
- before：73c9add冻结运行源，家园和平原/森林各一张；镜头/Seed尽量一致，但启动帧和角色姿态不同，不声称逐帧严格对照。没有同输入before短片。

短片、包、浏览器和公开版本以随后实际收据为准。当前未签最终美术、真机FPS、完整音轨或玩家认可。独立图像评审见 [independent_review](independent_review.md)。原森林空间轮廓、根形构图和整区品质的旧问题不因换细材质自动完成。

## 来源与失败保留

新增图片共8次生成：天空、山脊、前景、风车、森林树皮、小敌与三体remaster共7次采用，荆棘重绘1次因布局/方向错误拒绝。原图、Prompt或明确未恢复项、处理脚本与来源记录随assets保留；模型/价格接口未暴露。新荆棘沿用旧alpha/端口/危险语义并加入细纤维，不冒称全新轮廓。素材许可证分别记录，不把所有素材合称CC0。

失败包括首轮天空shader内TEXTURE不可见、sampler参数后台编译错误、采集退出的Script/Shader引用泄漏、global transform snap锚点漂移，以及第一段电影切图未回HOME。全部保留原日志；成功重试不追认原失败。电影首次实际录到18秒后第二图入口拒绝，不能作为完成短片交付。

## 恢复

`bash tools/godot.sh --path .` 是正式游戏；`--script tools/capture_fine_space.gd -- --output=res://build/fine_space_05/<fresh>` 采定位图（宿主timeout180s）。`tools/capture_fine_space_movie.gd` 录真实家园输入及两图连续相机诊断。离线重建用四个 `build_*fine*.gd` 和 `build_underworld_foreground.gd`，完成后editor import。生产源checkpoint见Git；未合main。
