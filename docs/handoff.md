# 当前会话交接：平原十关随机与音符永久升级

2026-10-10 UTC，分支`feature/plains-ten-generated`，从干净`feature/plains-capability-generation@cc2b933`创建；已重新读取origin/main（64ec8bb），主线尚不含前序未合并PR，采用叠加开发，不覆盖main或旧缓存。设计先行提交`5fcc4d5`；实现提交`cbe610c`，已创建[PR32](https://github.com/zhipijun1996/gunman-rush/pull/32)，base feature/plains-capability-generation（PR31）；后续证据仅见Git HEAD。前序完整记录见[归档](archive/handoff_plains_capability_generation.md)。无自动合并、无强推。

## 已实现范围

用户D054/D055授权最新美术、平原正式10关各自独立随机、类型差异及金币局内/音符永久。本轮按设计→新增模块/算法→类型消费者/十关→永久钱包与存储→实际Web验证分阶段完成。

- 最新手绘来源`feature/painterly-plains-v2@3bacc32`选择性导入13PNG；背景/草木平台/锯轮和安全点共用皮肤，不合并旧工程。角色新稿枪画进身体、不支持独立瞄准，保留正确独立枪角色；未过接缝rock_fill不用，未用原件排除导出。具体见[美术报告](latest_art_integration.md)。
- 新增45px微台阶、120px草甸缺口、连续双75px梯田、先降回升谷段、1120×700固定Boss核心。复用15种生成模块及现有尖刺、多尺寸锯轮/高级挑战；无绿色连接段/中间ENTRY EXIT。
- `PlainsStageGenerator`按stage index/type/current capability选择early/mid/late/service/boss；独立map seed，金币房降压力并散落，商店/回血低压无环境机关，道具保持二选一。只支持当前已验证端口链/镜像/高差，任意转折图与方形不冒称已交付。
- 首页**10 rooms / Windchime Plains**实际运行1–10；每关新地图/镜头/边界/安全锚点，双出口只提交一次且第9必Boss10。Boss随机入口、固定核心；核心进入才启动，缓冲免Boss伤害、退回不重置HP/phase/奖励。金奖一次后biome_complete回家园。旧固定3/10和练习入口保留。
- 散落金币入RunWallet，音符入Meta钱包。拾取在伤害批次后校验、环境回退不重抽不重发、零血同帧取消未提交拾取。音符成功拾取即保存、死亡保留是D056暂定demo政策；无兑换。家园永久生命三级，候选售价5/10/15音符、每级下局基线HP+1。
- `MetaSaveService` schema2、原子文件替换/备份/坏档保留、v1迁移、未来版本拒写；Web localStorage完整信封checksum+同步读回确认。收据与钱包/升级同事务，失败不扣/不发，不是云同步或续局。
- 几何Manifest v6：plains-capability-run-6 / coincident-capability-budget-6，旧v5明确拒绝。RunManifest记录各关实际地图、配置、HP/永久升级基线、类型内容和合法选择；不是运行快照。

## 实际验证

Godot **4.7.2.stable.official.ed1daf0bf Standard**。工具经`bash tools/godot.sh`，不使用裸系统4.6.3。日志在不提交的`build/verification/plains-ten/`，截图见`build/verification/plains-ten-browser/`。

| 命令/验证 | 实际结果 | 范围 |
| --- | --- | --- |
| python3 tools/check_docs.py / check_world_design.py | 退出0 | 文档/链接/58任务依赖/16候选地区，非物理 |
| python3 tools/check_art.py / check_painterly_pack.py | 退出0 | 91旧素材、13新PNG/20帧来源与定义 |
| timeout600 python3 tools/run_tests.py（内部540） | 5703断言/0失败，退出0 | 原完整回归；故意失败probe另实际退出1 |
| timeout420 Godot tests/plains_ten_generation_runner.gd | 1967/0，退出0 | 40个独立十关manifest；新4跳模块各双镜像，代表1/5/8关及Boss完整真实Motor路线/全身扫掠/接缝资源 |
| timeout120 Godot tests/plains_generation_runner.gd | 1870/0，退出0 | 旧平原专项，包含在旧回归范围，不重复累计 |
| timeout60 Godot tests/plains_weak_capabilities_runner.gd | 456/0，退出0 | 0动作/弱跳/弱反冲1–10能力筛选，仅契约非真实全链 |
| timeout120 Godot tests/plains_ten_app_tests.gd | 114/0，退出0 | 实际App十关/双出口/各类内容/金奖/回退/致死竞争/Meta新局基线/JSON重放；注入位置/伤害，不是物理十关通关 |
| timeout90 Godot tests/meta_notes_save_tests.gd | 39/0，退出0 | native真实存储、损坏/零字节/备份/拒绝/迁移/幂等/JS桥接类型；failure probe40/1实际退出1 |
| timeout60 Godot tests/painterly_skin_runner.gd | 18/0，退出0 | 皮肤/比例/viewport覆盖，非视觉认可 |
| timeout300 python3 tools/build.py web | 退出0 | 最终本地PCK **212641aed7ad**，约8.1MiB，未用源资产过滤 |
| timeout300 python3 tools/build.py windows | 退出0 | 单独Windows导出；不等于实际Windows游玩/存储 |
| timeout260 python3 tools/verify_plains_ten_browser.py | 7项/0失败，退出0 | 本地Chromium真实GUI，最终包212641aed7ad，首镜像接缝220→−14、暂停取消held aim、手绘合屏、升级购买与真实刷新 |

新专项5suite合计2594断言，加旧5703共8297；浏览器7项另计。真实GUI存储专项使用明确独立9音符fixture，真实按钮购买5后刷新仍4音符/等级1；不代表游戏赚音符或GUI通关十关。初始与刷新包脚标均212641ae。实际详见[GUI报告](plains_ten_browser.md)。CI接入`python3 tools/run_plains_ten_tests.py`，逐suite有界并检查成功统计，缺少完成行/脚本异常/非零均失败。

## 发现的失败与修复

- 零机关预算误禁全部候选导致服务房间只有平板：修为非机关候选可抽并加内容断言。单终点双出口范围重叠/弱能力偏移离开地面：改为沿停靠方向内收、nearest选择，交替两出口验证。
- JSON int加载成float导致严格收据/版本比较误拒：保留枚举/数字完整性约束，用规范化数值比较，实际重载验证。
- 首次真实Web购买失败退出1：JavaScriptBridge返回int1，int/bool比较产生SCRIPT ERROR；改为显式类型判定，重新导出后实际购买/刷新通过。失败文件保留，不以native30项通过推断Web通过。
- 两次GUI OCR数值/文字裁剪失败：目视原截图确认0与JUMP正确，仅调整0/O数字读取和文字区，不改游戏或放宽物理标准。详见GUI报告。

## 未验证与下一任务

Android/iPhone Safari真机完整十关、手感/触控/性能；Windows实际输入/存储；全部Seed/机关相位、GUI真正拾取音符与Boss操作、任意逐节点转向/方形图、最终美术认可均未验证。Android新APK未构建，Steam/云同步/续局/剧情/其他地区不实现；本轮不更新角色核心动作、不新增爬墙消费。

下一步先用户横屏试玩平原10关，按反馈调整预算、敌人/机关交错和平台读图；补金币/道具/商店/Boss真实GUI操作、音符真实拾取跨刷新及Safari存储。随后制作连续挑战大模块与真正分叉/折返拓扑，逐样片真实Motor验证后入池。指定GOLD贴墙缓降仍WALL-SLIDE-01计划，不混入当前平原必经。永久事务账本未来压缩须保持去重与存储拒绝语义，不能重发老收据。


## 远端首轮与继续记录

[实现CI 38029771473](https://github.com/zhipijun1996/gunman-rush/actions/runs/38029771473)旧完整5703/0通过，但新增PNG检查因Python3.12干净环境缺Pillow而失败，Windows/Web/部署均被跳过；不声称首轮发布成功。已加入固定Pillow12.3.0 requirements（官方PyPI实际核实）及有界CI安装，并重跑。此修复不更改任何运行资源/参数。

追加真实音符拾取GUI探索两次均未达成，移动只至−121/−127、NOTES仍4，触屏多指序列结束横移；无新游戏脚本错误，但不可宣称已取得音符。原最终包212七项通过报告单独保留。可选`--collect-notes`必须真实拾取→回家→刷新才通过，失败非零；后续先修测试触屏事件序列/实际手动验证，不通过改游戏降低条件。

## 远端复验与公开部署

运行代码与CI修复提交`5bbc34d`的[复验38030702436](https://github.com/zhipijun1996/gunman-rush/actions/runs/38030702436)已成功：旧5703/0、新五组2594/0，美术检查、Windows导出、Web导出与Pages部署均通过；Android任务未请求而跳过。后续交接提交仅更新验证文档，未改运行代码。

公开[试玩](https://zhipijun1996.github.io/gunman-rush/?v=5bbc34d)实际包`ed504122edb4`，8,480,476字节。下载公开PCK计算完整SHA256 `ed504122edb48442ae790519eb63caa40e6da346eaf18bac1a6ba72d7385f4ec`与上述CI导出日志完全一致；不是旧包925ddf2a1123，也不要求不同机器的包等于本地212641aed7ad。首页选择**10 rooms / Windchime Plains**。

Cloud通过GitHub下载Web artifact被其Azure附件地址返回403；未声称附件已下载，改用公开PCK与CI日志核对。构建附件仍在上述运行页提供，403不影响实际Pages部署。CI全文、公开元数据与哈希证据在忽略目录`build/verification/plains-ten/`，原本地GUI证据另外保存在`build/verification/plains-ten-browser-local/`。

公开包真实Chromium触屏模拟再次执行`timeout260 python3 tools/verify_plains_ten_browser.py 'https://zhipijun1996.github.io/gunman-rush/?v=5bbc34d'`：7项/0失败、退出0，实际加载`ed504122edb4`。首接缝WORLD X220→−32、ROUTE1/10→2/10、CAMERA−400；同一个9音符独立fixture经真实按钮购买与真正刷新保持4音符/生命等级1。截图和报告在`build/verification/plains-ten-browser/`、运行日志`build/verification/plains-ten/public-browser.log`。仍不代表游戏实际赚音符、完整十关GUI通关或Safari真机。
