# 固定地图 930001 开发入口

这是 map-gen 0.1.0 的固定地图宿主接入。**可启动和局部实测不等于全图自然通关认证**。本轮不装入生成算法，不扩展其他 seed。

## 启动与操作

从仓库根目录执行：

```sh
bash tools/cloud_setup.sh --godot-only
python3 third_party/mapgen/0.1.0/verify_delivery.py
bash tools/godot.sh --headless --editor --import --path .
bash tools/godot.sh --path . scenes/mapgen/seed_930001.tscn
```

引擎固定为 Godot 4.7.2 Standard。正常主游戏启动入口仍然是 `scenes/demo/demo.tscn`。

- A/D 或左右键移动；Space 跳跃；鼠标左键按住瞄准、松开射击。
- E 原生钩索；W 请求交互；S 穿透单向平台。起点先射中风铃再向右行走。
- M 或「全图」按钮显示带实例 ID 的实际世界总览，暂停且取消旧输入。
- Esc 或「暂停」暂停/继续；F5 或「新一局」创建新的玩家、钱包和 run identity。
- Enter 或「返回主游戏」回正常主游戏标题。原生宝箱二选一打开时由该弹窗持有暂停，地图/全局暂停不抢占。
- 手机复用主游戏 TouchOverlay，手柄复用 GamepadAdapter；本轮未签真机。

本开发入口在新玩家出生时一次授予物化 Route 声明所需的原生 grapple，基础跳跃/射击沿当前主游戏配置。没有改重力、速度、跳跃高度、射击次数或反冲参数；接口不重新授予能力、玩家或资源。

## 接入结构

`third_party/mapgen/0.1.0` 是交付包原字节副本。外层 `.gdignore` 防止 Godot 写入原包；运行时逐项核 manifest 全部文件，导出插件原样打入 PCK。`verify_delivery.py` 仍可直接验证该目录。

`materialized_registry.gd` 接受物化内容，先注入独立派生构建入口再入树。读取原场景只为取得其原生行为脚本，不实例化原场景地形。`materialized_terrain.gd` 构建唯一原生 PlatformingModule/实体/机关/敌人/奖励；`gear_seal.gd` 安装全部 40 个真实碰撞封口。只应用 `origin_blocks * 128`，不重新镜像、不应用 `source_affine` 或原场景偏移。

11 个派生入口复用各版本原生绑定，保留单向平台、刺面、方向机关、配对机关、折线轨迹、移动平台和敌人。椭圆原安装器不认识镜像符号，适配定义显式存储 `ellipse_x_sign`、圆心和半径，避免 Resource.duplicate 丢状态。

全图只创建一名现有 PlayerMotor/PlayerController，共享 FrameDamagePolicy、DemoLifetime、RunWallet、MetaProgression 和 PlainsRegionState。稳定身份为 `run_id / map_id / Mxx / local_id`。没有模块切换或地形流送；回程保持所有现有实体。受支持奖励房可通过 registry.unload→instantiate_materialized 在同一 registry/player/wallet/lifetime 中恢复已领取状态；HQ 奖励配对机关在 bind 前恢复。其他复杂敌人/移动机关/Boss 的卸载会明确拒绝并保留活实例。没有完整跨进程局中存档接口。

Boss 绑定主游戏正式 `windkeeper_storm`。从 M40 真实物化平台推导支撑和安全站点，第三阶段按明确适配替换 Platform0 的断桥；初始其他地形与 exit 封口保留。原生伤害批次确认胜利且玩家存活后结束当前 lifetime，显示本局已有金币；不虚构奖励、不把封闭 exit 当战后路口。死亡沿原生 player_fatal，结束同一生命周期。同帧死亡优先于胜利。

## 验证命令与范围

```sh
python3 tools/run_mapgen_delivery_tests.py --suite all --output-dir build/mapgen_930001/new-acceptance
# 可单独定位：inventory / controls / spawn / seams / seals / mechanisms / rewards / boss
```

输出目录必须是新目录；非零退出、缺 marker、未覆盖所需 case、脚本错误、退出泄漏和源漂移均拒绝。所有诊断明确标记 fixture：只有 spawn 的 M01 开铃→M02 是连续自然输入；其他接缝使用真实玩家形状扫掠，向下单向接缝再用原生 drop_through；奖励和 Boss 初态位置是局部 fixture，不能宣称从出生自然到达。Boss 战内没有传送、补血或调参。

实际数据、首轮失败及剩余缺口见[验收记录](../../evidence/mapgen_930001/README.md)；宿主资源差异见[兼容审计](../../evidence/mapgen_930001/host_compatibility.json)。

## 已构建的本地 Web

冻结源b2f71528、build054648325c2e的ZIP在 `build/mapgen_930001/mapgen-930001-web-054648325c2e.zip`。解压，执行 `python3 serve.py --directory . --port 8807`，浏览器打开 http://127.0.0.1:8807/。这是实际本地浏览器验证的固定地图开发入口；完整PCK和ZIP指纹见验收目录build.json。独立公开Preview的staging被既有900MiB容量守门拒绝，没有新公开网址。
