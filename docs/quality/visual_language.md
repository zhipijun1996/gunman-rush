# B「雨釉与偏心」：实际作品与未通过边界

本轮基于 PR73 最新开发树 `5c1e6549987e1e68c846302e9595a106ca1d79e7`，分支 `feature/visual-language-production`，没有从旧 main 开始、合并 main 或推广候选资产。任务 `VISUAL-LANGUAGE-01`。用户选定 B 方向；具体母版、实机和商业品质均未获用户认可。

## 先看作品

- 同题探索：[A 芦苇与缝补](../../assets/visual_development/proposals/a_board.png) / [B 雨釉与偏心](../../assets/visual_development/proposals/b_board.png)。两张都由真实图生工具制作；六类普通对象与相同功能段落用于比较。概念画的布局没有像素级一致，也没有严格满足正常16:9相机，因此只证明方向探索。
- [B1图像母版](../../assets/visual_development/master/b1_master.png)：普通造型、材料、选择性轮廓、明暗块、功能开口与整屏关系。母版内四格是教学示意，不是四次真实制作历史。
- 实际两次编辑：[明暗原件](../../assets/visual_development/props/value_block.png) → [材质编辑](../../assets/visual_development/props/material_pass.png)。[过程与单物件替代法](../evidence/visual_language/recipes.md)保留真实工具输入及失败边界。
- [原生反冲画面](../evidence/visual_language/media/candidate-recoil.png) / [同条件旧画面](../evidence/visual_language/media/before-recoil.png)；[遭遇](../evidence/visual_language/media/candidate-encounter.png)、[回望](../evidence/visual_language/media/candidate-lookback.png)、[返程](../evidence/visual_language/media/candidate-return.png)。这些是 Godot 电影实际抽帧。
- [候选正常速度片](../evidence/visual_language/media/candidate-normal-60fps.mp4) / [旧画面正常速度片](../evidence/visual_language/media/before-normal-60fps.mp4)，均1280×720/60fps，无加速。不是概念图或宣传片。
- [实际A截图的绘改目标](../../assets/visual_development/master/paintover_target.png) / [灰度检查](../evidence/visual_language/media/candidate-recoil-grayscale.png) / [640缩小检查](../evidence/visual_language/media/candidate-recoil-640.png)。绘改未烘焙成背景；后两张仅诊断变换，不能冒充设备验证。
- 独立上下文的短需求迁移：[森林第一图](../../assets/visual_development/transfer/forest_transfer_v1.png) / [第二图](../../assets/visual_development/transfer/forest_transfer_v2.png)。仅概念候选，未接入Godot，未用其替代失败的平原准入。

**当前结论是 REWORK，首G2未通过；没有合格黄金空间、第二结构、多Seed或最差Seed证明。** B 的普通对象与实际角色确有共同语言，连续草海、动作窗和功能区分有实质改善；地形侧面仍有巨大矩形平铺接缝，薄草沿没有建立顶/侧体积。停止本轮纹理覆墙方法，不以更多素材、技术通过或文件数冒充艺术进步。[最终独审](../evidence/visual_language/final-b1-live-independent-review.md)保留具体原件、观察范围和否决原因。

## 同题选择与可见语言

| 方向 | 情感与来源 | 如何改变普通对象 | 取舍与风险 |
| --- | --- | --- | --- |
| A 芦苇与缝补 | 柔软仍在承受逆风；弯芦、种荚、层木、旧布，水粉干笔与断墨线 | 信使斜衣摆、壳形普通敌、叠木棚、受力缝线；植物细长弧与建筑绑接互相呼应 | 保留风向与修补关系，拒绝到处贴齿轮；小尺寸细线容易噪化，部件接头成本高 |
| B 雨釉与偏心 | 温暖容器仍在维持脆弱秩序；盘筑陶、树节与蛋彩块面 | 低重心不对称体量、厚开口；人是短斗篷与实脚，树保留木叉，建筑为矿物盘筑；金属限必要夹具/轴，不铺装饰 | 强化普通物亲缘与小尺度读形；拒绝全屏灰暗/糖果感，防止釉斑和裂纹又淹没大体积 |

最初作者偏A，独审基于实际普通对象与缩小读形推荐B；用户原话“B 雨釉与偏心：圆润低重心、盘筑陶形、蛋彩明暗”。这只确认方向。B1给正面示范：装置上口两足、敌人侧口三足；叶、布、陶、金属分别用团块、顺褶、厚破边、少量硬高光，不给所有材料同一种噪声。实机只完成部分：Hero基础状态、RootBell身体、锯盘、树屋装置及HUD配色；跑步A/C近似、另18动作状态、完整HUD绘画和旧攻击特效仍未完成。

## 真正阻碍在哪里

1. **描述一致性没有提供绘画答案。** 基线art-director已列比例/笔触/光照，visual-director已有先构图，scene-composer已有层次；却没有先实际比较六种普通物如何用同一大形、明暗和边缘成立。旧岩纹、钟肋与若干Atlas自然成为默认答案。此次实际A/B、B1与真实编辑链补上创作材料，不新建导演。
2. **资产包装规格与实际图像被混淆。** 两次props多对象生成都不满足严格等格，tree与hut互相污染；环境连接图也缺真实underside和坡角。按要求的网格直接消费只会把失败带进引擎。已停止第三次赌网格，改用稳定全局母版＋单物派生、实测非等格region/pivot/socket；原件不改，缺件不签通过。
3. **填充纹理承担了本应由绘画/连接结构承担的体积。** `VisualLanguageSample._terrain()`把高对比素材按world UV铺进polygon，`.6→1.8`只改变尺度，最终显出矩形循环，不能获得顶面/转面/侧面。美观背景对此无补救作用。此方法已证伪；下一个不同路线是曲线驱动顶面/转折/侧面大暗块/根基，先低频形体实机成立，再加少量方向性材质与匹配连接件。**本轮没有实现该替代路线。**
4. **连续空间不是独立贴片数量。** 首D中树岛带下漏天空、玩家叠树冠、根浮空；有界修正用单功能连续草海深度层替换两树带，树脚下埋25world，真锯按935源像素主径对应52world直径。这些在实机中保留了意图，但没有解决岸体问题。
5. **计划与实际能力须分开。** `visual_director.route()`仍是原host生产计划，不是独立图生服务或全自动游戏工厂。本轮由真实宿主调用imagegen、已有Skills与真实Godot消费者；短需求森林上下文自主设计并画出候选，但没有引擎资产准入，不能说一条Prompt已完成区域。
6. **导出原生消费者曾静默缺失。** `GoldenStage._ready()`原用`FileAccess.file_exists(art_path)`判断`.gd`，PCK重映射`.gdc`后跳过美术，启动烟测仍可绿。已改`ResourceLoader.exists`；显式评审入口核实际catalog SHA、敌人与锯消费者。第一本地包保留并标不可交付，替代包必须出现实际美术READY。没有用源码原生截图代签PCK。

以上是当前代码/真实失败的结论，不根据文件数判断冗余。第一手开发者操作与本项目推导分开见[短来源记录](../evidence/visual_language/first-party-methods.md)，没有复制参考作品的角色、场景或资产。

## 实际消费者、连接和世界关系

[候选catalog](https://github.com/zhipijun1996/gunman-rush/blob/0905516bb8c996a5f79ee4ac242ea0a0ab2205de/resources/visual_development/candidate.json)是唯一显式入口，默认空字符串，普通流程不加载候选；[实际图片依赖清单](../evidence/visual_language/asset-consumer-inventory.json)追踪角色/敌人/锯、地形lip与端头、树棚、装置和两远层。11个被引用源文件中含1个JSON，即10张图片；20,271,682字节是源依赖总量，不能称纹理GPU占用。19张全部源图共44,561,803字节，未用候选留在实验库，正常三平台export均排除整个实验目录。

真实站面来自同一3岸polygon，显式open-meadow实际删除两旧钟肋碰撞并派生Manifest，不是藏图留碰撞。原PlayerMotor/武器能力/资源/RNG/存档的133项声明核心源与PR73基线逐字节不变。原安全锚确认→装置保存的蓝色内片回响，射击/敌人pulse→簧片响应；布采用惯性响应，树/土/陶不共同正弦摆动。只读接受事件与原安全锚历史，不越权给奖励或改资源。装置是原收集/维持用途、风化破损、仍保存一次经过者节奏的局部关系；实际听感未验，不能因此签环境叙事完成。

端帽以真实outer standing anchor/inner socket接合，禁止将整端头旋转冒充坡角。缺underside、任意坡角、GPU外边与碰撞校准；无随机组合完备性证明。树/棚脚点和装置接口是可再次装配的局部范例，还没有被第二结构证实，不能称完整模块库。

## 验证、预算及边界

- 首D仅660ticks局部反馈，预算耗尽/返程未完，失败原件保留；第一轮整屏就独审REWORK，没有修完局部清单才第一次判断方向。
- a79冻结A/E都1116ticks/18.6833秒/1121视频帧，完整去返、4次射击、HP5、同session零回退。原严格比较器`comparable_for_review`；逐tick位置/速度/资源/输入语义/镜头、敌人状态与锯物理相位一致。实例ID、4tick事件ID、22tick墙钟差异原样保留，不宣称全部JSON相同。
- 无枪192tick零shot坠落、删恢复岸213tick一次shot坠落：原物理负例成立，原进程严格退出，无Godot ERROR/泄漏。
- 19适配测试、原普通家园19断言执行；图像/界面与完整CI分别记录。两次过早并行Harness检查各子项通过但source变动整组拒绝，保留失败，最终待文档收口后重验。未降断言、忽略Godot错误或跑无关森林维修。
- 预登记的多个真实结构Seed没有执行；目前Seed仍只是固定实验布局标识，不能宣称随机空间品质。因首G2未准入，第二空间及最差Seed审查未发生。
- 森林仅短题目＋正常Skills＋全局母版，由独立空上下文执行；当时master的production_examples还是空表，尚未接收后完成的两个制作范例，不能称成熟方法迁移。两次实际图生155.2秒；木纤维承重/园艺陶件区别于平原，但第二图比例偏大、非16:9、丢失敌人，保留为REWORK概念提案。[独审](../evidence/visual_language/forest-transfer-independent-review.md)不签实机或能力可达。
- 原生电影含音轨，作者/独审明确没有亲听或完整连续播放；已实际看全屏抽帧及联系表。没有真人试玩、手机/PC实体设备/手柄可玩性、市场或商业竞争力数据；软件llvmpipe录片速度不是性能认证。

[来源唯一入口](../../assets/visual_development/README.md)索引19次实际图生/编辑的原图、参考和SHA，模型、价格、token与商业许可未知不补造。任务首个观测16:06:56 UTC，约16:44首原生反馈、16:55首共同源码冻结，17:01首完整同条件A/E与普通回归完成；阶段并行，不能相加成工作时长。后续因实际PCK消费者缺失重录/重打包另计，最终时钟与实测阶段耗时见交付receipt。没有可比的旧方法同任务控制实验，不能宣称总成本下降。

默认新美术worker输入是母版JSON＋B1/B板＋两个短范例，已测文本4326字节/2图（另读AGENTS与相关功能契约）；未测真实旧/新token差，不能把入口精简当实际百分比节省。正常恢复使用已有Skills与评审入口，不加载全PR历史。

## 运行与恢复

```sh
bash tools/godot.sh --path . --script tools/spatial_golden_preview.gd -- --visual-layout=open-meadow --visual-sample=res://resources/visual_development/candidate.json
```

这是手动可逆候选，不注入能力/自动驾驶/写Meta。只需要旧画面对照时去掉`--visual-sample`，保留相同`--visual-layout`。简短新题从`$art-director 制作荆棘森林的一组普通对象和一个代表性局部空间`读取现有母版与范例，真实宿主必须拥有imagegen能力；本轮已证明可自主提出并画出候选，未证明自动完成合格引擎内容。修地形应从替代制作路线开始，不能把本轮REWORK改名后继续贴材质。

完整CI/正式发布仍未通过；PR72森林/encounter旧阻塞未修复也未绕过。本地评审包与准确版本以交付receipt为准，不冒称线上更新。用户仍可审美选择和亲自试玩，AI内部接受不等于用户或市场认可。

最终运行源为`425826e39f56c2a16ce445130c4352deb0d0b95e`。修复后A02/E02重新采集，每侧20张抽帧与前版逐SHA一致，原作者与独审实际复核关键帧；不将a79旧回执改签新源。[1179源路径Git原blob闭包](../evidence/visual_language/runtime-tree-closure.json)全同。[最终本地包receipt](../evidence/visual_language/delivery.json)：build_id `656c6a538740`，177.76MiB ZIP，内附官方Godot；解压`bash play.sh`。候选实际PCK已独立目录加载/严格清理，并取得[打包后真实画面](../evidence/visual_language/media/actual-pck-start.png)，[绑定](../evidence/visual_language/packed-consumer-binding.json)不扩大为包内全路线。原包没有美术，已不可交付；新包依然艺术REWORK、非发布。[实测阶段时间](../evidence/visual_language/timings.json)区分重录成本和并行阶段。
