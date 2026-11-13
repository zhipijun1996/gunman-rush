# P04 纸艺剧场实验

- 任务：PAPER-THEATER-01。用户授权独立的剪纸、水彩与抽象拼贴 A/B 实机实验；产出 PR，不合入 main，不替换正式美术规范。
- 基线：`4f2bb5e41573e930603789c64b52a0c15a6a3dc4`，分支 `experiment/p04-paper-watercolor`。P04 为“倒钟田垄”；世界内容身份 `4b006bc2c4e537bbac62e972739cdc2b8a41e7e18deccf67b5133e6858367c8b`。
- 写集：`game/experiments/paper_theater/`、两个 `tools/art/` 实验工具、本交接与任务表。正式入口、房间 JSON、碰撞、控制器、存档服务、Visual Bible 和素材原字节均不改。
- 引擎：沿项目锁定的 `4.7.2.stable.custom_build.gunman_sd1.ed1daf0bf`，GL Compatibility；使用同一自定义发行版的非线程 Web 模板，不混用官方模板。

## 运行与复现

```sh
python3 tools/setup_environment.py --godot-only
bash tools/godot.sh --path . res://game/experiments/paper_theater/paper_lab.tscn
# 可选 -- --paper=A / --paper=B / --paper=0；运行时按 0/1/2 切换。
DISPLAY=:99 bash tools/godot.sh --audio-driver Dummy --path . --script tools/art/paper_capture.gd
DISPLAY=:99 bash tools/godot.sh --audio-driver Dummy --path . --fixed-fps 60 --write-movie build/paper_theater/A-master.avi --script tools/art/paper_capture.gd -- --clip --paper=A
# B 同输入：换输出文件名与 --paper=B。
DISPLAY=:99 bash tools/godot.sh --audio-driver Dummy --path . --script tools/art/paper_capture.gd -- --measure
python3 tools/art/export_paper_theater.py
```

显示编号仅是本机示例；需真实 GPU/软件 OpenGL 显示服务。截图与视频不是 headless 空渲染。实验入口使用现有 `WorldRoomReview.MemorySave`，基础能力；普通试玩仍会受伤。录像显式打开现有隔离无敌选项以连续展示，不更改 Motor、反冲参数、弹药、危险恢复或镜头。片中不设置玩家位置、速度或镜头轨迹；初始位置沿 P04 自身起点。

## 现有渲染链的核对

| 范围 | main 的实际消费者 | 对实验的影响 |
| --- | --- | --- |
| 地形与碰撞 | `FixedWorldRoom._ready` 读取平台 Rect2、one-way 索引和 terrain_polygons；分别创建 StaticBody2D/CollisionShape2D/CollisionPolygon2D | 直接观察装载后的几何，不回写；边界来自 WorldRoomSpace，包含真实门洞与房界外实心区域 |
| 地形表现 | UnderworldTerrain 的原生 32px 纹理及独立砌体材质；PlainsRoomArt 负责木踏板、道具、危险外观、灯光和景深 | 隐藏原房间 CanvasItem 后另建实验视觉；物理、实体 AI 与交互继续运行。0 模式恢复原表现 |
| 角色与怪物 | PlayerPresentationRuntime 装配当前身体，EnemyPresentationBinding 装配怪物；多数素材 nearest 采样 | 隐藏原表现但保留其逻辑消费者；新纸偶只读 Motor、已接受射击/受伤事件和敌人 telegraph/attack 状态 |
| 空间层次 | 世界实体与地形 z 层、PlainsRoomArt 的 depths、固定地标/附着物；WorldCamera 唯一拥有正式镜头 | 保留正式 1280×720 与 zoom=1.6。实验层按自身深度移动；附着物倍率严格为 1 |
| 灯光与环境色 | CanvasModulate、室外 DirectionalLight2D、地形 LightOccluder2D、玩家 CarryLight | 纸艺模式隐藏原环境调制与灯；用一盏有限暖色随身光和静态接触影，避免重复照明。远景与角色不吃这盏环境光 |
| UI | 独立 CanvasLayer 的正式 HUD/触控与实验切换面板 | 不把 UI 当作本次纸艺人物/环境验收；无标注截图隐藏 HUD，操作片保留资源状态 |

本次选择 Polygon2D：可直接消费轮廓，支持凹多边形、抗锯齿及 CanvasItem 材质，规模适合单房实验。MeshInstance2D 可在后续把同材质面批处理，当前未为一间房引入网格框架。Sprite2D 适合有限的纸纹样本，但不能解决完整地形轮廓；保留 Tile 会继续留下规则接缝。SubViewport/屏幕滤镜不参与本实验，避免额外全屏渲染与纸纹随镜头滑动。

## A/B 的实际结构

| 层 | 实现 | 坐标与遮挡 |
| --- | --- | --- |
| 天空与切片日轮 | Polygon2D 底纸、圆片、独立窄云；B 用斜向空隙分割圆片 | 0.03 / 0.12 倍真实视差，无完整背景插画 |
| 三层远山 | 分别生成并保持独立节点的连续山脊 | 0.16 / 0.33 / 0.50 倍，低对比；覆盖完整 P04 镜头范围 |
| 远处钟架 | A 单拱，B 双拱和偏斜立片、悬钟 | 0.52 倍，与同深度山脚遮罩共用参照；不借近景平台伪装远处建筑根基 |
| 地形 | 对平台、边界及外部实心区域做几何并集；保留孔洞时拒绝误填，P04 得到 5 个连续主体轮廓 | 原碰撞不动；纸厚与短接触影朝右下；落脚亮边沿真实顶面。两条大色层裁在轮廓内 |
| 可下穿台 | 顶面仍沿原碰撞坐标，视觉只画薄纸托板；A 安静、B 非规则裁边 | 世界固定；明确区别于实体厚岸，不把原 Rect2 厚度画成假实墙 |
| 危险、藏箱 | 地刺形状沿 strip 实际范围，统一铁锈红；箱体沿真实交互宿主位置 | 世界固定；不增加危险或奖励。敌人预告由真实行为状态显示 |
| 纸偶 | 分片兜帽、外衣、围巾、脚与枪；怪物使用同一剪切、纸厚与色彩逻辑 | 只更新变换；枪口闪光消费接受的射击方向，腿/翼消费真实运动，接地影查询真实平台 |
| 附着前景 | 少量植物明确绑定平台坐标；局部接近角色时减弱遮挡 | 倍率 1，不随镜头漂移，不铺屏幕边框；保护落点与危险边缘 |

A：灰绿、奶油、克制的颜料变化；B：更强的赭黄与青绿、斜切日轮、偏斜建筑、更明显的纸层裁边。两版共用几何、角色大小、敌人和正式镜头，只在表现配方中分叉。

纸材质使用一个运行时生成的 512² FastNoiseLite 纹理，四次不同尺度/方向采样表达大片颜料、局部水渍、纸齿和纤维。采样来自纸片坐标，没有 TIME 或屏幕坐标；不使用 AI 图、场景插画、法线图或逐帧纹理生成。相同色材质共享；Shader保留父节点COLOR，真实帧缓冲额外验证透明度与受伤色调继承，确保附着前景的局部避让有效；纹理按不同尺度组合，有限源仍不等于数学上永不重复。可站立轮廓与危险不依赖噪声。

## 验收与结论边界

原始媒体、日志、性能 JSON 和哈希清单在 `build/paper_theater/`；持久交付入口与最终检查见本节的交付记录。捕获工具逐帧检查三种表现的镜头完全相同，并比较静态地形碰撞身份、确认实验层不含碰撞、稳定帧不重建几何与 MemorySave 隔离。此检查不冒充完整路线或审美验收。

| 表现 | 实际优势 | 实际不足 |
| --- | --- | --- |
| 当前像素风 | 成熟的动画/物种差异、互动和材质细节；当前软件渲染成本较低 | 砖面规律明显，桥体与部分插画道具的纹理密度不一；构件与素材族依赖较多 |
| A 轻剪纸 | 地形没有 Tile 网格，安静大面与薄台层次更易统一；动作和危险对比清楚 | 在开阔机位偏简，纸偶动作细节少于正式角色；仅靠矩形玩法地形仍会读成横向台阶 |
| B 抽象拼贴 | 轮廓、色块和钟架形成更强辨识度，人物与环境材质一致 | 大钟架在局部镜头较抢眼；异形构图需逐房编排，不能简单套用到16区；开销仍需优化 |

本实验支持“原生几何可以建立统一纸艺语言并消除本房规则贴图接缝”的结论；尚不支持“已优于当前全部美术”“可直接量产16区”或“达到手机帧率目标”。大体量来自少量独立纸层，不靠装饰数量。小纸片阴影已收敛，但绘制调用仍是主要扩展成本。下一步应先在真实 Android 浏览器测量，并在低顶/室内第二房检验材质、根基与纸偶动作，再决定是否投入新的正式渲染体系。

### 交付记录

- 审核/手机试玩：[独立纸艺剧场](https://clock-paper-theater-p04.zhipijun1996.chatgpt.site/)，owner-private，由创建者账号访问；正式主站和关卡工作台未覆盖。
- 九张原始同机位图：[断桥A](https://clock-paper-theater-p04.zhipijun1996.chatgpt.site/media/A-bridge.png) / [断桥B](https://clock-paper-theater-p04.zhipijun1996.chatgpt.site/media/B-bridge.png)；站内另含当前像素、上层和桥下对照与逐张原图下载。
- 正常速度视频：[A](https://clock-paper-theater-p04.zhipijun1996.chatgpt.site/media/A.mp4) / [B](https://clock-paper-theater-p04.zhipijun1996.chatgpt.site/media/B.mp4)，各20秒、1280×720、60fps、约1.9MB，含原游戏声音；无敌夹具在画面明确标注。已查看编码后的动作帧，没有变速。
- 运行源码：`02c88d7141702c2e53577fe0babac9cbefaeb2d8`；非线程Web build `e172d8b9ab95`，PCK 137,906,204字节，校验1,364项资源与149项原始源。共享正式运行资源使首次网络量约142MB，纸艺本身没有新增场景PNG；本轮没有为缩包重构装载器。
- `python3 tools/ci.py`：四项通过，退出0；`tools/art/paper_capture.gd`：35项、0失败；A/B连续输入分别8次接受跳跃/射击，均停留P04。独立PCK空目录启动沿同源包检查；最终Web包另在Chromium实际启动。
- Chromium/SwiftShader 844×390实际WebGL2/WASM启动，触控移动、跳跃与B→A切换已看图核实；唯一HTTP404是浏览器请求favicon.ico。不是实体手机或Windows验收。
- 实测绘制调用：当前83、A171、B176；纸艺主轮廓5个，纸面242/251个。单个512²程序纹理、4次材质采样、一盏有限动态光，无SubViewport或逐帧几何重建。[原始记录](https://clock-paper-theater-p04.zhipijun1996.chatgpt.site/media/performance.json)中云端软件渲染计时抖动明显，不把均值当硬件FPS结论。
- 技术结果与艺术判断分开：本次实验和对照交付完成；质量卡仍将正式替换门槛标为failed，将设备性能标为unverified。A比较安静但偏简，B辨识度更高但局部钟架抢眼；纸偶与物种细节不足，不建议直接扩16区。
- 下一动作：在同一Web build的实体Android浏览器测量，并选择低顶/室内第二房验证，再决定是否继续投入；本PR不合入正式游戏。
