# 平原当前交接

## 范围与来源

分支 `feat/plains-v07-complete`，PR142草稿，接续PR141；本轮WORLD-CAMERA-03基线e0cdd1f0。当前正式开放03→21→22→23→24→01六房，35房/43接缝及L01东行、26双吊台职责保留，其余29房内部待迁移。

用户纠正：Boss不得改变缩放，只缓慢移到战场边界；上下观察只作微调，必须检查原地跳、登高及下降。前版把全场可见误解为缩放，把房间构图偏置拿来作跳跃摆幅，且只验原地跳；技术通过不能代表用户认可。规则直接重整[正式镜头规范](../../../bible/room_authoring.md#正式镜头)。

## 当前实现

WorldCamera仍是唯一正式控制器。删除Boss合屏缩放，战斗保持探索1.6，只以0.65秒阻尼向战场合法构图平移，放不下一屏时有限跟随。普通动作偏移围绕既有基础构图变化，按可见高度1.8%、上下各最多8wu封顶；空中0.16秒、落地0.30秒阻尼。保留跟随锚点，不在起落时切换锚点或强制角色居中。显式下降预读、快速下落追赶、水平前瞻、左杆查看、隐藏交接和生命周期保持。角色物理、输入及关卡布局未改。

## 验证与交付

本轮日志/正常速度短片归 `build/camera-subtle/`。37项实际输入覆盖原地短跳/满跳、连续三级登高与下台、竖井下降、Boss入场恒定缩放和边界；原36输入/镜头、118区/隐藏/比例、10实际动作、六房连续教程及预读/恢复回归通过。CI四项和24世界单测通过。已审看原地跳、三级登高、三级下台和Boss入场的连续抽帧。四段正常速度视频使用e0cdd1f0前版与当前同组输入；Boss仍为P14隔离夹具。Web启动/移动跳跃/地图/暂停、触屏查看及取消、逐房存档隔离、短片播放和下载已复验。自动通过不等于用户对手感认可。

公开build `d4e11d5d3f96`，导出源码 `f56f7eda5d6b9d98809a7eeaf6ed25650c32cc19`，prepared `91504c91b636a8faadad48788e800b60377e8e0f`；[部署42569096442](https://github.com/zhipijun1996/gunman-rush/actions/runs/42569096442)成功。线上版本及19份页面/短片/ZIP/总图与本地一致。

- [连续试玩](https://zhipijun1996.github.io/gunman-rush/?v=d4e11d5d3f96) / [六房入口](https://zhipijun1996.github.io/gunman-rush/replays/?v=d4e11d5d3f96)。
- [四段前后短片](https://zhipijun1996.github.io/gunman-rush/camera-review/?v=d4e11d5d3f96)：Boss、原地跳、登高、下降，每段3～5秒。
- [新版短片下载，约3.4MiB](https://zhipijun1996.github.io/gunman-rush/camera-review/camera-after-clips.zip?v=d4e11d5d3f96)。
- [35房路线/职责/收集/Boss/休息站总图](https://zhipijun1996.github.io/gunman-rush/map-review/?v=d4e11d5d3f96)，本轮未改。

## 剩余工作

本次不扩建地形。22完成侧回程板、24载具外观、整体材料层次与其余29房的内部/能力锁/收集返回/连续主环待制作。全区玩法与视听未终审。实体手机/手柄、完整Web路线及设备性能未验证。Boss使用既有P14隔离夹具，不代表当前六房可达。

正式槽原生 `fixed_world_plains04_construction.json` / Web `plains04_construction`；逐房只用内存。后续读取现行镜头规范及本交接；遇未决冲突问用户。PR142不合并。
