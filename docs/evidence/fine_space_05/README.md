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

## 最终交付（已实际核验）

[公开视频/实机图评审页](https://zhipijun1996.github.io/gunman-rush-previews/reviews/FINE-SPACE-05/efd7843/)；[MP4下载](https://zhipijun1996.github.io/gunman-rush-previews/reviews/FINE-SPACE-05/efd7843/fine_space_05.mp4)。这不是可玩网页。Pages39837638359实际success，host b73353c；公开完整MP4/精选PNG SHA与本地一致，Chromium已实际加载全部图并播放视频超过1秒。新电影为24.3667秒1280×720/60fps、48k stereo；前12秒真实Home输入，随后2×6秒活场景连续镜头诊断，包含加载/清理帧；没有同输入before电影。

最终运行源码 `efd784349efa31502cb428b14bde10ea517bdd9a`，图像母源与上一轮静图为 `5ce3cd3d8771d6e44d00cc600b0a73ddb1e6b0a8`，之间只有Godot UID和HUD边界修复。已观察movie_r2诊断中的HUD裁切，改为以实际panel尺寸/viewport clamp候选；正式图二5个实际镜头、42项检查0失败且确实选到底部572px槽，独审限定关闭此缺陷。movie_r3最终退出0无脚本/shader/泄漏错误；旧片失败保留。

Web build `524396d0cd10`，PCK150455860字节、SHA `524396d0cd10dc78226bb7e2fb590bd091870dbd5be444f3e15d2e0c475f288b`。原导出/包/28项新增资源闭包通过；本地Chromium5案例：真实Home走跳、mouse平原1/2与森林1、DOM touch平原2，实际入口/完整HUD/暂停恢复，errors=[]。真实随机Seed/Manifest在browser.json。没有将模拟触屏签成设备或把入口签成全路线。

**公开可玩Web未发布**：原stage-preview实际拒绝重建后超过900MiB；现有历史及主站保留。尝试独立新托管仓库实际返回 `Resource not accessible by integration (createRepository)`，未提权或修改容量守门。评审页24MB可在原cap内发布。可操作本地原Web包 `/workspace/artifacts/gunman-fine-space-05-web-524396d0cd10.zip`，解压在目录运行 `python3 -m http.server 8000`，打开localhost:8000。普通ENTER HOME；DEVELOPMENT DEMOS→SELECT REGION→PLAINS MAP1/2。新包含原许可和新来源记录。

`/workspace/artifacts/gunman-fine-space-05-visuals.zip` 包含30实机图、最终MP4/轨迹、证据和73c9add至efd7843的binary patch。最终直接MP4 `/workspace/artifacts/gunman-fine-space-05.mp4`。所用新母版/构建记录和14份machine asset record实际保留在源码；前景原始prompt因上下文压缩未恢复，provenance明确标记not_recovered，不捏造原文。

剩余：森林裸细木台与苔草根台造型仍需统一，家园标签对比偏低；平原前景很稀疏且一个样本opacity≈0.00458，不能凭数量签空间效果。30个记录的完整前景边界+3wu与实际功能/HUD矩形重叠0，仅签采样窗口。完整影片视觉/音轨、全动态遮挡、实体设备FPS、全部旧入口及玩家最终评价未验。完整CI/Harness未跑，源码分支保留且不合main。

最终Web ZIP314939189字节，SHA `4247192709e96cc19d0e9f73d76c6dda941ee418d098a8cf5584391e570040df`，ZIP每成员读回无错误。
