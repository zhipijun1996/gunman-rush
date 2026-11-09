# 平原当前交接

## 范围与来源

当前源码按PR142最终实现与PR144、PR145整合，验证入口见[整合交接](../pr_integration_141_145/scope.md)。正式开放03→21→22→23→24→01六房，教程房本轮灰盒重做与对应验证见[手机工作台交接](../mobile_level_workbench_01/scope.md)，下述镜头证据只覆盖其所述版本，不代表新五房完整体验。35房/43接缝及L01东行、26双吊台职责不变，其余29房内部待迁移。

镜头规则统一见[正式镜头规范](../../../bible/room_authoring.md#正式镜头)，Boss边界必须独立对照实际墙位。

## 当前实现

Boss左右展示边界取arena_bounds的左右墙/封门坐标；相机中心范围按实际视口半宽内缩，左端画面左边贴左墙、右端右边贴右墙，震动也不得越界。余量参数改为仅上下的arena_vertical_padding；没有新增末端坐标覆盖。WorldCamera控制器、1.6缩放、0.65秒入场平移、上下各最多8wu动作偏移、角色物理及地形全部保持。

## 验证与交付

本轮日志/短片归 `build/camera-walls/`。camera_arena.gd在P11/P14两种既有场地和1280×720/960×540视口下，使用实际输入走到两侧碰撞封墙；独立量测最终画面边缘等于封墙坐标，并检查震动不越界、缩放不变，共36项通过。边界夹具在真实激活后暂停Boss AI，起点定位显式隔离；不代表完整Boss战或主线可达。原37纵向/场地和10实际Boss/H/恢复回归、CI四项、24世界单测、文档检查通过。已审看左右贴墙画面；Web启动/移动跳跃/地图/暂停、触屏查看及取消、逐房存档隔离、短片播放/下载已复验。

公开build `c9a4725df221`，导出源码 `db4635dfb5af9f40d9c722f6cffc89739ee28555`，prepared `9e63f9ae969f5f7610af5b78ed1ff6f30b7fd774`；[部署42570535122](https://github.com/zhipijun1996/gunman-rush/actions/runs/42570535122)成功。线上版本及16份页面/短片/ZIP/总图与本地一致。

- [连续试玩](https://zhipijun1996.github.io/gunman-rush/?v=c9a4725df221) / [六房入口](https://zhipijun1996.github.io/gunman-rush/replays/?v=c9a4725df221)。
- [三段前后短片](https://zhipijun1996.github.io/gunman-rush/camera-review/?v=c9a4725df221)：入场、左墙、右墙，每段约4秒。
- [新版短片下载，约1.7MiB](https://zhipijun1996.github.io/gunman-rush/camera-review/camera-after-clips.zip?v=c9a4725df221)。
- [35房路线/职责/收集/Boss/休息站总图](https://zhipijun1996.github.io/gunman-rush/map-review/?v=c9a4725df221)，本轮未改。

## 剩余工作

本次不扩建地形；22完成侧回程、24载具外观、材料层次与其余29房内部/能力锁/收集回返/连续主环仍待制作。全区玩法美术未验收。实体手机/手柄、完整Web路线及设备性能未验证。

正式槽原生 `fixed_world_plains04_construction.json` / Web `plains04_construction`；逐房只用内存。后续读取现行规范及本交接；未决冲突问用户。后续以main作为新任务基线。
