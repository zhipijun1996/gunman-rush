# 从世界结构重建平原：实际制作实验

任务 `PLAINS-WORLD-REBUILD-01`；独立分支 `feature/plains-world-rebuild`，母PR89/28236ef9。用户本轮明确授权不兼容旧平原几何与失败画源，保留核心操作、战斗、输入、资源、保存、敌人基础与有效测试。森林未写。所有新内容为显式候选，不进正式池。

## 三种实际方法，而非三轮装饰

1. `e76e5c24`：完整世界实体先行，碰撞与绘画域共源；但按岸体宽高归一投射源图。实际首片根须拉长、草缘截断、远景裁边，独审REWORK。
2. `5871a02b`：全深度新画源、固定画尺、用世界边界反求源边界；数值UV越界真实失败后修复。真实下溪反冲往返通过，实图仍有竖缝/拖色/镜像重复，独审RETHINK。停止该算法，不再加细节救场。
3. `87f1e299`起：从源画构造反向生成世界。有限完整手绘地貌保存源轮廓、可信接触线、画幅与等比frame；碰撞、路线、树棚依附从它共同派生。直接呈现源图，不将任意多边形反投影、不分割草带；独立东岸地层和浅溪源解决具体形体缺口。当前验证与最终准入以独审03和结果索引为准，不能从方法描述推导成功。

源图全部实际调用 image_gen.imagegen，原图未程序绘画或滤镜改造，商用许可未独立核实。来源见 `assets/visual_development/plains_world_rebuild/provenance.json`。源绘画是有限地貌单元，不含人物/UI/整屏背景，远景、树、建筑独立层组装。它们不是每个Seed重新图生。

## 数据与消费者

`resources/generation/plains_world_rebuild.json` 是本候选唯一构造目录。`PlainsWorldRebuild` 产出 source polygon、可信接触、paint_frame、完整实体、路线、根部连接与构图依附；`PlainsWorldRebuildStage` 安装真实CollisionPolygon2D和现有敌人；`PlainsWorldRebuildComposer` 消费同frame。外部目录重建并拒绝错源、非法缩放、轮廓/碰撞/接触伪造，核真实PNG尺寸与SHA。

v3只是一种首构造。Seed当前明确只记录，不产生不同结构；未以hash/机关相位宣称随机关卡。第二布局及整区扩展必须以首构造实际艺术/操作准入为前提。无完整区域/Boss流程或市场事实声明。

## 真实启动与短反馈

```sh
bash tools/godot.sh --path . --script res://tools/plains_world_rebuild_preview.gd -- --seed=world-rebuild-01
python3 tools/run_plains_world_rebuild_tests.py --help
```

手动使用原输入、真实少女外观/战斗/HUD/镜头，不写存档。工具支持原生合同、headless真实输入main/lower轨迹和正常镜头电影，headless不输出假截图。先验证真实跳跃/反冲输入，再拍正常速度片。首次9tick短按导致失败保留；完整跳保持修的是测试驾驶策略，没有修改Motor或缩短裂隙掩盖。

旧网格消费者测试仅适用于冻结v1/v2；原件与SHA保留。v3用真实Sprite源图/等比变换/源轮廓与物理逐点对照、接触面实际不透明支持替代已退役consumer专属UV断言。核心1310原测试不变，最终适用运行版本另列。实际看图、电影编码/抽帧、完整播放/听音、真人/设备、用户审美均分开记录。

## 最终实际入口与恢复

[作品/电影](gallery.html)、[根因与边界](findings.md)、[实际交付](delivery/README.md)、[原始结果索引](records/index.json)。当前运行源 `ba787df7261dba40f75409a3b99457dd9bbef985`；首完整片97703a8f来源不改标。恢复工作应另开worktree，切此运行提交，不覆盖其他会话。

```sh
python3 tools/level_design.py route --request '从源画重建风铃平原连续地貌与美术' --output build/world_rebuild_start.json
python3 tools/harness.py --check plains-world-rebuild-contract --jobs 1
bash tools/godot.sh --path . --script res://tools/plains_world_rebuild_preview.gd -- --seed=world-rebuild-01 --variant=1
```

第一命令本轮已实际调用，只生成绑定现有production_loop的计划；必须由宿主领取执行，不是整区自动完成承诺。已注册原生合同用于短反馈；完整GUI实际录像使用 `tools/run_plains_world_rebuild_tests.py --help` 所列 `--capture --route --route-kind main --variant 0/1` 参数（先查真实CLI，不拼旧工具参数）。main/lower是实际输入驾驶，手动preview不自动驾驶。第二种布局保持主要四源不变；不得从本例复制坐标称新区域生产。

后续第一实验限定为一个外侧截面真正接入第二实体，继续同frame派生接触/碰撞/路线，验证正常镜头连接和真实往返，成立才扩完整区域。本轮未消费接口不能当已可无限延伸。风格仍P1候选，用户最终审美、商用许可、真人/设备/完整CI/Web均未签。
