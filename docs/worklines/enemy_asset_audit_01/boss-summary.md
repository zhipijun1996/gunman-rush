# 现有 Boss 资产事实盘点（只读）

快照 `310c0421e18829088a4d2208c5f1b6cba3db35dc`。8 个 scene、9 个 Definition 组合；Storm 是同一 Windkeeper scene 的正式资源覆写，**不是第9个Boss物种**。未运行Godot、未写仓库、未生成或编辑图，也不评价被拒制作质量。

| 场景/组合 | 当前入口边界 | 实际主身体/动作素材事实 | 设计资料 |
|---|---|---|---|
| Clockwork | 固定demo/旧Boss Lab | clockwork_atlas中phase1/phase2/dead三个静态键；代码动作 | 泛用Boss契约+atlas说明；未检索到专Sheet |
| Bellstrider | 当前平原图1 | 独立128×114静图；轮/悬挂代码；旧SVG/空间机身仍留存为别版 | 平原Bible§6.1、D077压力Boss设计、连续战斗preflight |
| Windkeeper 默认 | 旧scene默认窗口配置 | 与Storm完全同128×119静图；旧v4六关键姿态只在另一渲染分支使用 | D071、运行切片、平原Bible§6.2 |
| Windkeeper Storm | 当前平原图2资源覆写 | 同图；不是独有新母版/动作页 | D077强化、连续战斗preflight、同一Bible |
| 旧Thorn Guardian | 森林v1显式回放 | 与V2完全同guardian.png（1×）；静图+代码 | 未检索到旧seed-window独立Sheet；区域/通用资料散落 |
| 旧Thorn Queen | 森林v1显式回放 | 与Weave/Canopy完全同queen.png，仅2×接地显示 | 未检索到旧场景独立Sheet；区域/通用资料散落 |
| Rootbell V2 | 当前森林v2/v15图1候选默认 | 同guardian.png；实体Bell/扑落/返击主要为代码/共享机关铃 | 独立rootbell_guardian_v2专卡+历史257行记录；限定准入 |
| Weave Queen V2 | 历史迁巢织场/旧layout pin | 与Canopy同queen.png和同1×悬浮bounds；网结/网带代码 | 专卡明确整体未通过，保历史CONTINUE/REVISE范围 |
| Canopy Queen | 当前森林v2/v15图2候选默认 | 同queen.png；单静体+代码动作，2网机制 | 独立Canopy v3专卡；有限整合且整体/H核心REVISE |

当前主分支合计只追到 **5个主身体PNG文件**：Clockwork atlas、Bellstrider、Windkeeper、森林Guardian、森林Queen。森林Guardian/Queen同出一张fine remaster三体母版（第三个是普通甲虫），各是单姿态裁图。共享helper、通用受击扇形、网带和波纹不能记成每Boss独有动作/特效素材。

留存原图包括：Underworld双Boss原始页及Windkeeper去胸铃编辑页；旧Windkeeper六姿态页与parts；Bellstrider旧SVG、spatial actors/chassis；森林native1字面像素源与fine32重绘原始母版。JSON按“当前消费/另分支可达/历史未直接消费”分别列出，没有把旧Definition或存档版本计成新Boss。

音频：GameAudio共享cue+用户选声，平原与森林Boss各一首地区BGM；查到两区Bible的角色声景文字及全局音频目录，但未找到8个场景各自完整专属声效包。原命名windkeeper_roar.wav等仍在音频inventory，当前Boss脚本不直接加载它们，不能只看名字就认定正在使用。

缺失/未知：未找到各Boss完整独立转面/结构设定表与当前主身体的完整逐帧动作包；Clockwork三状态、Windkeeper六关键姿态均不是完整连续序列。Bible终结演出文字不等于已有对应分镜/专素材。故事G0表里森林“冠枝鹿/护巢兽”与当前Guardian/Queen场景是不同层资料，未据此新增角色。仅检索当前树与相关历史文档，未穷尽归档压缩包/远端/未上传原稿。

完整路径、章节、SHA、尺寸、实际消费者、共享关系、历史别版、VFX/音频来源和每项未知见 `boss-inventory.json`。
