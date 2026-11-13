# B · 三域纸艺剧场实验

用户原话：“不用a了，b继续实验3个区域对比”。本轮只保留 B 抽象拼贴，A 的运行分支、按钮、当前图集和视频退出，旧结果由 Git/旧 Site 版本追溯。这是方向选择，不是正式美术终审。

- 延续 PR159 / `experiment/p04-paper-watercolor`；最新 main 与原基线均为 `4f2bb5e41573e930603789c64b52a0c15a6a3dc4`。
- 三个区域各一间现有真实样房：P-R04、F-R01、G-R02。森林/工城是当前已施工入口示例，不是三个完整区域改造。
- 写集：`game/experiments/paper_theater/`、`tools/art/` 三个实验工具、本交接/质量卡/任务表。正式入口、房间 JSON、碰撞、控制器、存档服务、素材与 Visual Bible 均未修改。
- 沿项目锁定 `4.7.2.stable.custom_build.gunman_sd1.ed1daf0bf`，GL Compatibility，同发行版非线程 Web 模板；正式世界身份仍为 `4b006bc2c4e537bbac62e972739cdc2b8a41e7e18deccf67b5133e6858367c8b`。

## 三域造型与空间

| 样房 | B 的独立造型 | 主要检验 |
| --- | --- | --- |
| 风铃平原 / P-R04 | 斜切日轮、非对称双拱铜钟、赭色薄台与青绿断桥。 | 开敞留白、横向跨距、危险边缘与高台回望。 |
| 荆棘森林 / F-R01 | 非等距树干、叠叶冠、月牙负形、根部与纸枝踏面。 | 上下层次、密度变化、树根固定和镜头移动时的前后关系。 |
| 齿轮工城 / G-R02 | 固定钢纸壁板、双窗光、铜钟盘、缓转机械片与金属折片前景。 | 室内无天空、壁板世界固定、装配根基和局部光影。 |

共用同一纸偶、角色身体尺度和正式镜头（1280×720、zoom=1.6）。区域差异来自独立几何构图与附着关系，另配各自色板；没有把同一个背景换色当作三个区域。

- 地形观察装载后的 Rect2/Polygon 与 WorldRoomSpace 边界，生成连续轮廓与裁在内部的色层。碰撞、门洞、薄台与落脚面仍由原房间持有。
- Polygon2D 正面、纸厚和短接触影在装载/切模式时建立；静止与移动帧不重建几何。工城齿轮只更新刚性变换，不重建顶点。
- 一个512² FastNoiseLite纸纹与四次不同尺度采样表现颜料、纸齿和纤维。Shader保留父级COLOR，真实帧缓冲检查alpha与闪色；没有AI图、完整背景插画、SubViewport或全屏多次滤镜。
- 平原远景0.03/0.12/0.16/0.33/0.50/0.52倍；森林远树0.22/0.46、上冠0.7倍，各自树脚由同深度地床遮住。平台附着物均倍率1，根部来自明确宿主；接近角色时局部减弱遮挡。
- 工城室内壁板、窗、钟盘与管件均倍率1，没有室内天空或近墙漂移。窗光为背景平面；共用一盏有限的角色动态光，天空/远景/角色保持独立可读色板。
- 隐藏原房间 CanvasItem 后，新表现也读取原 door_open 显示闭门纸板，避免留下不可见的真实阻挡。藏箱/受伤/射击/敌人预告仍消费真实已接受状态与事件。
- 原 Sprite2D/nearest、地形生成、PlainsRoomArt/RegionThresholdArt、CanvasModulate/Light2D 均未替换正式消费者；0 模式完整恢复当前表现，B 模式另建隔离纸层。

## 入口与复现

```sh
bash tools/godot.sh --path . res://game/experiments/paper_theater/paper_lab.tscn -- --room=F-R01
# 支持 P-R04 / F-R01 / G-R02；默认 B，--paper=0 为当前美术。
# 运行时 1/2/3 切区域，B/0切表现；触屏按钮复用项目现有触控桥。
DISPLAY=:99 bash tools/godot.sh --audio-driver Dummy --path . --script tools/art/paper_capture.gd
DISPLAY=:99 bash tools/godot.sh --audio-driver Dummy --path . --fixed-fps 60 --write-movie build/paper_theater/F-R01-master.avi --script tools/art/paper_capture.gd -- --clip --room=F-R01
DISPLAY=:99 bash tools/godot.sh --audio-driver Dummy --path . --script tools/art/paper_capture.gd -- --measure
python3 tools/art/export_paper_theater.py
python3 tools/art/package_paper_review.py /absolute/site/dist
```

显示编号只是本机示例。截图/视频均实际渲染，不以headless加载代替画面。样房使用 WorldRoomReview.MemorySave；切区和重置都留在隔离存档中。操作片明确标注现有无敌审核夹具，不设置片中玩家位置、速度或镜头轨迹；每秒60个物理tick对应1秒影片，仅裁启动段与编码，不变速。P04为20秒、8次跳跃/射击；F01/G02各15秒、各4次，三个片段均未离开目标房。

## 当前交付与结果

- [三域审核与手机试玩](https://clock-paper-theater-p04.zhipijun1996.chatgpt.site/)，保留原网址与owner-private权限；正式主站和工作台未覆盖。
- 风铃平原：[试玩](https://clock-paper-theater-p04.zhipijun1996.chatgpt.site/play/index.html?room=P-R04&paper=B) / [B原图](https://clock-paper-theater-p04.zhipijun1996.chatgpt.site/media/P-R04-B-landmark.png) / [正常速度视频](https://clock-paper-theater-p04.zhipijun1996.chatgpt.site/media/P-R04.mp4)。
- 荆棘森林：[试玩](https://clock-paper-theater-p04.zhipijun1996.chatgpt.site/play/index.html?room=F-R01&paper=B) / [B原图](https://clock-paper-theater-p04.zhipijun1996.chatgpt.site/media/F-R01-B-landmark.png) / [正常速度视频](https://clock-paper-theater-p04.zhipijun1996.chatgpt.site/media/F-R01.mp4)。
- 齿轮工城：[试玩](https://clock-paper-theater-p04.zhipijun1996.chatgpt.site/play/index.html?room=G-R02&paper=B) / [B原图](https://clock-paper-theater-p04.zhipijun1996.chatgpt.site/media/G-R02-B-landmark.png) / [正常速度视频](https://clock-paper-theater-p04.zhipijun1996.chatgpt.site/media/G-R02.mp4)。
- 冻结运行源码 `e79a56f1e275e0312faf318a56759a13d7b0a9d5`；Web build `dc2b8c720877`，依赖闭包 `60e5f8c3ddef7678679bfe55997793384baffb5dd1d3ec9d55837929f9152333`，PCK 137,912,964字节，核对1,365项资源与149项原始源。首次共享下载约142MB，之后缓存复用。
- 三域18张当前/B同机位原图，机位与SHA见站内capture-manifest。真实窗口专项87项、0失败：每房碰撞身份、机位、无表现层碰撞、固定附着、稳定帧、内存存档、选房重置及GPU透明度/闪色。
- `python3 tools/ci.py` 四项通过、退出0；原检查和敏感断言没有删除、降低或改写。
- Chromium/SwiftShader 844×390真实WASM/WebGL2已启动。CDP真实触屏依次切P04→F01→G02→F01，工城当前/B切换及移动看图核实，无脚本错误；仅favicon.ico出现404。不是实体手机性能背书。
- 编码后的森林/工城运动帧已审看；原图与视频在build/paper_theater，站点媒体与冻结文件按哈希核对。没有用测试条数代替合屏判断。

| 样房 | 当前 / B 绘制调用 | B Polygon2D纸面 / 主轮廓 |
| --- | --- | --- |
| P-R04 | 88 / 181 | 248 / 5 |
| F-R01 | 87 / 161 | 251 / 1 |
| G-R02 | 77 / 147 | 72 / 1 |

计时来自云端Mesa llvmpipe软件OpenGL，每种表现采样240帧；原始process时间保留在performance.json。工城纸面较少仍有多层照明/线条调用，不能用纸面数量推算成本。三域B绘制调用均高于当前表现；没有签署Android/Windows帧率。实体设备与浏览器仿真分开。

## 比较判断与剩余边界

平原的留白与铜钟、森林的树冠负形与根部、工城的壁板与机械圆片已经形成三种可辨的空间性格。统一纸偶、接触影、落脚亮边和水彩颗粒可以复用；森林首轮等距树冠已返工为非均匀疏密，P04双拱比例已收敛。三个房内未出现Tile网格，镜头运动时世界附着物未漂移。

本轮通过的是用户授权的“三域B样房比较”范围。仍保留上一轮限制：纸偶动作和物种细节较简，几何化长树干/大钟盘的精细程度有限；F01/G02本身是轻量入口样本，没有完整战斗，不能证明深层区域遭遇可读性。需要实体Android性能、更多房型和正式美术终审后再考虑16区量产。本PR保持草稿，不合入正式游戏；下一动作先看三域原图与运动，再选择B方向的具体返工目标。
