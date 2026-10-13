# PLAINS-TERRAIN-02：已认可美术正式接入

基线 main `a9a9cd2738fdb45c967f05c5a5495d072d922945`，分支 `feature/painted-terrain-production`。2026-10-13 用户原话及认可范围保留在 [原始反馈](../evidence/terrain_production/user_approval.json)。

目的：用户从标题→家园→平原时直接看到已经认可的水粉石灰岩，不必打开 Lab。两张正式地图、地面、墙面和实体空中台共用并集边界，移动实体使用同源材质但固定身体局部纹理相位。可穿透木桥仍保留原木桥语义；不把它画成封闭石墙，不宣称所有木桥资产已经重制。复用现有母版，不新增 AI 资产或修改物理、生成算法、资源和奖励。

实现：PlainsRegionStage 自身安装既有 PlainsTerrainStudy 表现组件（保留类名/UID）；开发入口仅启用额外对照 UI。实际碰撞几何变化仍驱动表现刷新。移动平台只挂可视子节点，物理携带由原 AnimatableBody2D 负责。1 行长度×厚度样板和默认两图回归进入现有 harness。

| 条件/场景 | 方法与通过结果 | 失败条件 |
| --- | --- | --- |
| 正常启动、第二图、重开 | 引擎正式消费者 + 标题/家园真实 GUI；默认显示新美术，没有比较按钮 | 只 Lab 可见、后续地图退回旧版、比较 UI 泄漏 |
| 极短/一格/多格/非整格空中台 | 8–640 长、8.5/24/32 厚度；几何覆盖及实际 GPU 分块像素对照 | 越界端头、顶底遮盖、接缝、空域被填 |
| 移动平台 | 节点挂在实际运动体，局部材质坐标；移动纹理不在表面游动 | 世界 UV 导致纹理滑动、增加碰撞体或搬运玩家 |
| 状态和几何生命周期 | 保留并运行旧破桥/恢复测试，加正式默认入口测试 | 假落点、旧图形残留、Manifest 改变 |
| 接口及画面 | 既有 47 邻接与 GPU 分块验证，查看正式截图和单行样板 | 绘制错误、旧缓存、把自动几何通过当美术通过 |

质量记录：[十一维状态](records/PLAINS-TERRAIN-02.json)。用户已认可原合屏风格；本轮独立审查未执行，手机实测、背景底部断界和其他敌人/Boss 缺陷未关闭。自检结果不冒充独立审查。

实际命令、退出码及精选截图在 [证据目录](../evidence/terrain_production)。完整临时日志位于 build/verification，按运行版本归档。

## 实际交付验证

冻结最终运行/样板版本 `cc46ae46b67a169528d46866eb35cf3724074d78`，实际浏览器 build_id `891445822cb8`。本轮只按授权晋级美术，未改变游戏版本号。

| 实际命令 | 结果 / 退出码 |
| --- | --- |
| `python3 tools/harness.py --profile full` | 26 检查通过 / 0；Core 5942、历史 43 组、正式 region 15 组；运行中工作树快照/差异原样留存 |
| `python3 tools/harness.py --profile web` | 干净冻结 cc46ae4，12 检查通过 / 0 |
| `python3 tools/run_terrain_production_tests.py` | 冻结 cc46ae4，230 断言、0 失败 / 0 |
| `python3 tools/run_quality_review_tests.py` | 冻结 cc46ae4，1044 断言、0 失败 / 0 |
| `python3 tools/verify_terrain_tiles_browser.py http://127.0.0.1:8766` | 三种分块 GPU 像素对照均无差异，通用引擎/WebGL 错误为零 / 0 |
| `python3 tools/verify_terrain_production_browser.py http://127.0.0.1:8766` | 正常标题/家园/平原，移动、跳跃、暂停，无开发比较控件 / 0 |

完整日志和执行版本见 [命令](../evidence/terrain_production/commands.json)。全量回归启动于实现中的工作树，报告保留源码哈希；随后 gallery 标签/间距和 fixture 清理在冻结 cc46ae4 上专项与 Web/GUI 复验，不能把初始全量报告冒充冻结提交的运行。

精选截图：[正式合屏](../evidence/terrain_production/formal_gui/formal-entry.png)、[单行平台长度/厚度](../evidence/terrain_production/gallery/single-row-whole.png)。正常速度录像保留在相邻目录。

新增自检失败：样板 %g 标签不受 Godot 支持，旧 GUI checker 漏报普通 ERROR；原报告已明确撤回，改 %s、拓宽错误检查并重新拍摄。样板标签间距也按实屏复核修正。首次把技术探针报告直接当画面通过不可接受。

性能/设备维度仍 unverified。headless 专项偶发退出 Ogg 音频资源警告，verbose 指向 land/death 播放对象，原件保留；没有把这些运行标为“零资源泄漏”。独立审查本轮未执行，同一会话的 [自检](../evidence/terrain_production/self_review.md) 不代签。G3 的正式消费者维度通过，但整门仍因性能证据缺失未验。

Git 交付：[PR60](https://github.com/zhipijun1996/gunman-rush/pull/60)，用户已授权完全合入。main 的 CI/Pages 部署按实际工作流结果报告，Git 合并不等于设备验收。

### Git 凭据失效后的交付溯源

命令行 GitHub 凭据在交付时失效，改用已连接 GitHub App 上传同一 Git blob/tree。原冻结 cc46ae4 与 GitHub [af565d5](https://github.com/zhipijun1996/gunman-rush/commit/af565d519269076ed2abe9d25eea2c4bec02dd27) 的完整 tree 均为 `69f40aa3c2787a4a69ae3874a3196c1d0e39d812`。原始日志中的执行 SHA 保持原样，不伪称测试在重建提交上运行；[映射](../evidence/terrain_production/git_delivery.json) 和 [原提交 bundle](../evidence/terrain_production/verified-source.bundle) 可恢复精确版本。
