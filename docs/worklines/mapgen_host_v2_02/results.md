# PR127 A–E 修订与交接

继续 `feature/mapgen-host-v2-01`，起点 `9e97b553b7b51cbc64922ed94281061202e3e58b`；PR base仍为main `30e36c9abe223f26e666ceaf796e3fe9cb58e10f`。没有从main重做或恢复PR123。本页接替第一轮关于权限、弱map_hash和Web未接通的历史状态，不回写其受证文件或原失败。

实际运行/导出冻结源 **F=`67da2f3596880cbdad22496a649dd68f7af7d5a6`**。之后的交接提交只保存文档/质量/证据；全部5775份本地实际非文档Git源另有SHA向量，与F及最终提交逐字核对。最终PR head和该head CI结果以[PR127](https://github.com/zhipijun1996/gunman-rush/pull/127)为准，不把F的执行改签成别的Git提交。

## A：旧CI与历史证据

原run41510336068/head9e97的实际172项为：87通过、1失败、84未执行、0复用；serial80通过，parallel quality退出1，affected因失败lane拒绝。错误为FUTURE-FEATURE-ARCHITECTURE-01的scope字节漂移，不是超时或游戏断言失败。

`95cd283d`恢复 `architecture_extensions.md` 与 `architecture.md` 的main原字节。前者8059B/SHA256 `2c3ba48c3df480d643ec5ee19a9f5d9fd300e6862f34f6d7238b8c29e64b2e87`，与旧卡原SHA及原证据提交一致；旧卡完全不改。新导航只在本任务、current_state/handoff。原API事实、两个phase ZIP、报告和日志留在证据归档。原172/预算/断言不削减；最终head仍由现有Production impact完整双通道验证。

## B：协议权限

`25eb0978`修复 `RuntimeMapV2Provider`：仅接受公共枚举 **INPUT/OUTPUT/INOUT**。非法IN/OUT、小写、空值和非字符串明确返回 `permission: invalid protocol value`；合法INPUT/OUTPUT若用于切片内部接缝，返回 `host capability unsupported for legal …`。目前真实所选接缝仍只支持INOUT，没有假装已实现单向物理/Route限制。

原INOUT真实装载正例保留；新增八个权限值的准入/拒绝测试。最初非字符串反例暴露typed-array/比较错误，原失败保留，类型守门修复后158/0，后续身份专项扩展至199/0。

## C：正式参考包0.2.0

`2e0c497c`接入开发CLI `tools/verify_mapgen_reference.py`。先核外ZIP SHA，再按上游安全规则解压，在无关cwd以 `-B -I -S` 调原 `reference.py verify/replay --case all`。实际覆盖成功样例及SEARCH_EXHAUSTED拒绝样例；拒绝样例验证通过不等于生成成功。

- 发行/PR head：`0d338c2309d4e17bd8e9b128f745eb93938e99b2`。
- ZIP：1869684B，SHA256 `25f05861b68a99eee1e9d588eb2cab761e30c85b7cc109b0536292fcc98867f6`。
- 包内记录的实际代码源：`1b20031c60ee0269d03c1e89eb52f0a0f0fc70bf`；不能混称发行提交。原算法基线178c4016、module-pack1.1.0也分别保留。
- 成功样例与宿主完整map、M16/M18/M21三content **4/4逐字节一致**，不替换源数据，不改seed/config/filter/目标。工具只在开发输出目录提取，不写宿主资源。
- 三个实际拒绝例：外ZIP改字节；合法ZIP但host副本ellipse sign变化；包内content改动并重算清单后仍由原语义验证器拒绝。原资源不覆盖。

包的readiness仍明确 `reference-only`，Godot/Web运行时算法NOT_IMPLEMENTED。本轮只证明冻结数据装载，不把Python当游戏算法。复现见[参考包操作](reference_package.md)。

## D：三个身份与恢复

`a408edfc`完善纯数据Provider，仍不调用算法、节点或地图随机数：

| 身份 | 实际含义和绑定 |
| --- | --- |
| generation_input_fingerprint | 上游generator.request_fingerprint原样保留；不改写，宿主变化不冒充重新生成 |
| map_content_identity | v2协议、generator实现/算法/来源、模块包、原map字节SHA及实际map数据、三份实际加载content的原字节与数据摘要、原content_version |
| host_load_identity / plan.map_hash | `gunman-rush/runtime-map-load/v1`、adapter版本、map_content_identity、排序选择范围、selection字节、bindings schema/version/字节/实际内容、当前spawn binding与位置、region/map index及已有capabilities |

摘要沿原Godot sorted-key JSON惯例，启用full precision。Byte SHA由文件I/O边界核验；同时摘要实际Dictionary，避免改内容后仍沿用旧SHA断言。它仍不是任意不可信v2的通用认证器。content scope明示 **loaded_instance_refs_only**，未签未加载43份内容。

bindings新加宿主schema/version（`loading-slice-r1`），三处实际出生位置不变；input-lock只同步该成员实际SHA。RunManifest独立slice output记录完整身份，不塞旧generated_layout。`reload_slice`先读新Plan、用新hash恢复；拒绝发生在清输入、epoch失效、旧Stage释放及服务替换之前，并返回具体错误。

199项实际专项覆盖：合法新content、微小浮点content、bindings内容/版本、选择、实现/来源、模块包变化都拒绝旧恢复；host-only变化保持map_content身份；键序/等价选择顺序不改变身份；旧R1弱hash记录明确拒绝。真实Stage在旧状态不匹配时不建几何。原PlainsRegionState版本2和永久存档schema完全未改。

## E：实际Web与退出

`ac041157`沿原机制接入：Web Playtest preset只追加7个确切JSON；原 `runtime_contract/check_runtime_closure`核锁与实际PCK原字节；Python scene准入只增加本scene精确例外，邻项/遍历仍拒绝。`resources/`脏源守门原本就有，审计误报已独立撤回，没有重写该守门。

独立scene明确声明自有音频，原bootstrap不再为其额外建GameAudio；老场景行为保留。`close_preview`委托同一个 `close_slice`，`preview_exit_requested`让Web ESC走原宿主菜单；宿主await原音频排空后再移除场景。原三case保留，新增真实packed slice/唯一音频/按钮路径和真实ESC共45/0。加载/physics/closed诊断只观察实际节点，不写位置或资源。

原Foundry导出basis守门确实拒绝旧数据；按原工具重验36片段+18路线并stamp后，`67da2f35`仅提交56个派生JSON。独立逐叶比较只变化basis/hash/manifest_hash（164/108/54处），其余全部相等，不替换普通地图、几何或规则。

实际Web build **ca7b47b3f398**，PCK216993944B，SHA256 **ca7b47b3f3980630f46eb4c318319f93f628ce5918acf54a8ef775fa35efafa1**。七份raw JSON逐字节/SHA读回；完整闭包16 JSON/8 raw PNG/13 textures、pending0；包内无Python、ZIP、docs/tools/tests。初次闭包因旧imported缓存软链指向工作区外而拒绝，缓存迁回项目内后原检查通过；未放宽guard。局部预览副本只用原inject_entry改HTML，原build/report/PCK不改，仅本地COI server，无发布。

实际Chromium两个全新context，总249.218s/原300s：D180ms x+56.333435，A180ms x−56.333435，观察到grounded；平台实际运动，最大观察位移315.798wu。OCR识别后真实点击FULL GAME/MENU及真实ESC，各先closed（audio_released=true/lifetime_active=false/stage_detached=true）、再原menu log、最后真实标题页。6张PNG逐张目视；host identity两次均与原生匹配 `6b7a05c197663e1396e1177f2fe76a7b0dc5eeff1a898259ac5a3b8a13044b9c`。原SourceRoot前后35183项及producer/helper/PCK稳定。

**保留原console诊断**：favicon.ico404一条，Emscripten主线程Blocking提示两条（type:error）；page_errors/request_failures/http_errors回调列表分别0，不代表console全零。不签Web跨接缝/骑乘、FPS、手机、整图或资源零泄漏；原生实际接缝/骑乘/严格退出专项另有证据。

## 本地检查、CI与下一批

受影响八类Harness fresh：slice199、cloud preview45、原LevelPlan146、RunSession61、Python delivery33、Web资源合同56、架构13、planner49，原预算不变。F源又fresh跑199/45，原生严格退出通过；实际Web/PCK与非作者独审另存。[证据入口](../../evidence/mapgen_host_v2_02/README.md)区分运行源、旧失败和最终Git/CI。

下一批优先 **M35 / game-plains-ferry-gears**，原content_version `sha256:18e0578b0631239884f0ff9bb598b04867396bcbe3988c036b512ebe32e092b3`，物化文件SHA `99de30fea7541920ba0d024372927dcee387c7da453916d9e3b05a7093214d1c`：完整4平台、1hazard、1saw、2linear ferry，无敌人/奖励/latch/HQ。先做完整单模块机制适配及共享伤害/时钟/取消，不删除危险物凑相邻切片；真实邻居仍另有未支持内容。之后可选M01真实safe_lesson bell/gate，出生/封口仍须单独绑定。两者均未在本批实现。

完整46实例、其余机制/敌人/奖励/Boss、正式App旧Manifest消费者、全能力快照、正式出生/终端、运行时算法调度仍是后续工作。本批不扩展、不合并、不部署。回退本批应成组回到95cd283d（保A证据恢复），不得混用新身份/旧状态或只撤bindings。普通出发地图和永久保存不受本切片撤回影响。
