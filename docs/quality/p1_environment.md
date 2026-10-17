# 风铃平原完整环境实验：三轮实机仍REWORK

最新实际作品：[整段37.32秒正常速度录像](../evidence/p1_environment/media/full03.mp4)、[三轮同窗口图像对照](../evidence/p1_environment/gallery.html)、[最终独审](../evidence/p1_environment/independent-native-03.md)。均为Godot正常相机、真实角色/敌人/锯/HUD与真实输入；概念母版不作实机证据。

![最新桥上真实站姿，视频8秒](../evidence/p1_environment/frames/round03_bridge.png)

![最新接收岸，视频6秒，仍不合格的端肩](../evidence/p1_environment/frames/round03_receiver.png)

**未达到精美黄金，未完成精美随机平原。停止当前端肩接法，不扩第二结构或Seed。** 共同画风、邮桥与谷地关系、深壁体积有进步，但根肩与自然转面仍脱开，连续空间的近中远层次也不足。AI内部判断不等于用户或市场认可。

分支 `feature/plains-environment-grammar`，基于最新美术PR81/e545b05e，最后实际运行 `4d4803773d21dbe9e9443b42bc0a87dbc35137c6`；之后只整理证据/质量/交接。没有从main重新开始，没有合main/强推/改森林生产文件。P1仍是用户偏好候选，未成为正式艺术权威。

实际版本与迭代如下；时间以原始receipt为准，影片时间与软件GL制作墙钟分开。

| 轮次 | 实际源 | 操作 | 实机艺术结论 |
| --- | --- | --- | --- |
| 1 | 3818b851 | 2233tick，21点去返，HP5，6枪，0回退 | REWORK：岸体裁直、整壁随坡剪切、草肩厚板；发现角色实际踩栏杆 |
| 2 | 1b755922 | 2234tick，21点去返，HP5，6枪，0回退 | REWORK但有实质进步：固定深壁、有限转面、新画踏面/HUD改善，端肩仍方切 |
| 3 | 4d480377 | 2234tick，21点去返，HP5，6枪，0回退 | REWORK：薄带裁剪/退出只把切口擦淡，没有画成共同转面体积，停止此接法 |

原比较器真实通过第2→3轮 `comparable_for_review`：同Seed、同Manifest、同实际多边形/锯、同路线，2234帧选定16项玩家/碰撞数值零差异；仅两美术源变化。不是宣称输入墙钟/对象ID/像素完全相同。第1→2轮含明确局部几何变化，不能称严格纯美术同条件。PR81→首轮的[原比较拒绝](../evidence/p1_environment/records/comparison_01/original_compare_rejection.json)与第2→3轮的[真实通过记录](../evidence/p1_environment/records/comparison_02/)分别保留。

这次实际做了完整母版、六张功能源和一次桥源编辑，共8次真实image_gen调用。源图/prompt/引用SHA/尺寸及未知模型/许可在 `assets/visual_development/p1_environment/` 与原质量资产记录。当前实际环境消费六张主要PNG（新桥替代旧桥），另复用既有少女/敌人/锯/界面；不是六张图代表完整游戏资产。没有逐Seed生成图片，也没有把整体母版挂成游戏背景。旧错误桥保留原件并标rejected_evidence_only，不进入正式池。

[共享计划](../../resources/generation/environment_grammar/lee_post_v1.json)经真实 `DemoApp→PlainsEnvironmentStage→Assembler→Module` 消费，五处所约四屏；真实多边形、站面、源尺寸、桥socket、四棚脚、锯、路线与景层不再各自猜坐标。新深侧、两桥基和10点新踏面属于明确的隔离实验几何，完整重新操作验证。PlayerMotor/武器/能力/资源/RNG/存档契约未改；原正式生成器/区域池不受此flag影响。当前只有固定结构A，Seed只改变原锯相位，**这不算结构随机**。四个[预登记Seed](../evidence/p1_environment/seed_set.json)因首段未准入而未执行，没有最差Seed结果，不外推任意地图质量。

根因已经超出“矩形碰撞”。将深侧改为自然多边形以后仍有拼贴：`PlainsEnvironmentTerrain._build_top_band`把连续草肩作为单独带面，原先直接截断；第3轮裁入轮廓并alpha退出后，也没有得到和侧岩共同绘制的转面。两张画分别好看、共同调色和统一锚点，都不能补出缺失的体积关系。母版的近中远围合还主要被拆成两张远层、前岸和独立大物，缺少能让进入/穿越/回望产生不同空间关系的中等尺度组合。这是制作分解与连接语法失败，不能继续加草、雾、图片数量或局部评分掩盖。

保留有证据的方法：原图同源派生、有限尺度源、安静深壁、真实踏面测量后共同改桥面/路点、逐棚脚支持校验、世界锚定景层。**不把整套失败地形接法固化为成功范例。** [制作入口](../evidence/p1_environment/recipe.md)已把停止原因放在最前；现有4个Skills与原route只做必要纠偏，没有新增导演或平行质量体系。简短 `制作风铃平原美术` 会生成绑定本次真实消费者/失败记录的原Harness计划，仍需要真实宿主执行；route本身没有自动完成native或艺术生产，独审已明确这个缺口。自动稳定创作精美整区的目标尚未建立。

真实工程证据：三轮import/解析、原生严格出退、44项工具/路由单测；同源no-gun仅抑制shoot请求而保留能力资源，344tick首裂隙失败、HP5→4、1自然回退，严格干净退出。它不证明所有无枪策略无解。两次JSON数型假设导致的attach失败与4 ObjectDB/2resource退出残留仍保留；正常路线干净不能代签该拒绝分支。第一次并发修改元数据使Harness冻结检查中断，另有错误Python模块调用导致import失败，均不改标准并在正确入口重验。未跑或宣称完整正式CI、旧复杂GUI清理/encounter历史阻塞已解决、Web发布、真人/手机/手柄验收或实际听音。独审看原尺寸离散帧，未完整播放/亲听。

[本地评审交付](../evidence/p1_environment/delivery/delivery.json)：Linux x86_64失败候选，build_id `35bfdf035cd7`，ZIP 239,813,534字节，SHA256 `4e6540e05fb0fce9dc874217929978fcf7b9451253bd80c87a87672ae5d4bee1`。当前会话产物位于 `build/plains_environment/local_review_02/plains-environment-candidate-linux-x86_64.zip`，解压运行play.sh；独立空目录headless/真实GUI/闭包/退出与ZIP检查通过，包内没有自动路线驱动或正式保存写入。包未重新整段路线操作；完整路线证据来自同冻结源，包另验证实际消费者和资源闭包。首包宿主无ALSA设备被原标准拒绝，第二次只给云机smoke显式ALSA null；玩家入口仍正常音频，未代签听音。恢复producer/路径清单/命令与所有失败日志已归档，不依赖旧包字节。

[时间记录](../evidence/p1_environment/timings.json)保存三次原生录制、编码抽帧墙钟（每轮约200秒）与8次图像调用；未暴露价格/模型及未完整计时的Agent阶段保持unknown，不补造精确成本。两相同PCK以SHA证明等效后仅物理硬链去重168,336,800字节，原路径/失败日志/ZIP不变；它是本机存储去重，**不是**资源包缩小或艺术生产成功。

最终冻结相关检查已完成：原Harness以docs/art/gameplay标签明确选择docs、quality、art-art、visual-director-tests、level-design-routing五项，均passed（targeted_checks=true），[原报告](../evidence/p1_environment/records/checks_final/harness/report.json)保留。单独44case原日志也在checks_final。没有放宽旧断言或宣称完整profile/正式CI。
