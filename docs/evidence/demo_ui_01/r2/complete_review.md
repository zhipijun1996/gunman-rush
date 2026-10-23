# DEMO-UI-01 R2：完整静态方向独立复审

审查者：`/root/independent_review`，非生产实现作者，2026-10-23。本次仅独立读取源码、实际打开 Godot 原始截图及核查已有运行报告；未启动引擎、浏览器或修改生产代码。使用仓库 gameplay-reviewer、visual-director、art-director 与 game-quality-gate 的适用审查边界。R1 的用户拒绝仍然成立，本报告不追认 R1。

## 判定与版本边界

**限定 ACCEPT：R2 标题、HUD 和原生圆角菜单的静态美术方向，适合进入本轮真实 Web 交互与用户评价。** 标题有显著改善，HUD 已形成比 R1 清晰的生命／精力／弹药层级。手机 HUD 初审发现的 R2-01 已由下方实际新图复审关闭；未观察的交互、动态、公开 Web 字体闭包与设备体验仍为 **UNVERIFIED**。不是任务完成、商业成品、用户审美、实体手柄／手机或完整 Release 认可。

审查时 HEAD 为 `e59d367a22cf57f1a1a3b208a44d032c4ea41c3c`；R2 为未提交工作区，不能把 HEAD 视为本候选源码提交。以下九个源码按所列顺序，以 `路径 UTF-8 + NUL + 文件字节` 连续计算的 SHA256 为 `19223adc197e35a72de668478b28609b2cbbca48718844c3ecb7ef7435c812f0`：`game_hud.gd`、`heart_strip.gd`、`resource_track.gd`、`clockwork_theme.gd`、`title_backdrop.gd`、`game_typography.gd`（均在 `scripts/ui/demo_ui_01/`）、`scripts/ui/demo_menu.gd`、`scripts/demo/demo_app.gd`、`project.godot`。源码后续变化需要对应增量复审。

## 实际看过的像素

逐一用图像工具打开，而非只读取文件名、哈希或报告：

- `build/verification/demo-ui-r2/direction/title.png`
- 同目录 `formal-hud.png`、`hurt.png`、`max-growth.png`、`touch-hud-844x390.png`、`pause-844x390.png`、`map.png`、`run-end.png`。
- `build/verification/demo-ui-r2/r2-direction-v2/title-844x390.png`、`title-844x390-bottom.png`、`settings.png`、`continue-saved-fixture.png`。
- 前次本独审实际打开的 R2 `native-v2/title.png`，以及恢复的 R1 `/workspace/recovery/demo-ui-01-before-r2-evidence/demo-ui-native-v7/title.png`，用来判断方向改善。

844×390 是测试窗口尺寸；截图实际游戏纹理为 **693×390**，不能冒称844px宽游戏画布或实体手机。未打开其余 v2 宽屏标题／教程／存档截图，未观看本轮连续影片或听音轨。

## 可接受的实际改善

标题的夕照钟塔、悬挂风铃、苔铜裂钟与摆锤徽章具有明确世界身份，左侧原生按钮与右侧徽章形成稳定主次。中文名称从初审的24px增至36px；最新手机首屏完整显示名称、标语及四项主操作，徽章没有再侵入左侧按钮。开发入口通过滚动到达；底部截图名称滚出视口是滚动结果，不是初始标题裁切。主操作铜金、次级深绿及焦点边线可区分，明显优于被拒 R1 的细线钟盘与工具入口气质。

生命成为独立小心形插槽；正常、受伤延迟金色、恢复青色与空槽在实际图中可区别。13.5上限展示14个实际容量槽并换行，尾槽按真实半单位容量填充，数值4.25/13.5没有被强改为整心规则。精力使用带射击成本刻度的横条，弹药使用独立弹匣图形，武器文字与金币／音符各有局部底衬。大块统一黑底板已移除，场景中部和人物轮廓仍可读。当前初始战斗 HUD 的层级比 R1 稳定。

菜单使用统一像素字体、铜边、圆角、底边厚度与克制阴影；主操作金色不是仅靠焦点框表达。设置与继续页的标题／说明／内容／操作有清楚层级。死亡结果页与 HUD 共用材质；未发现贴整张截图代替实际控件。手机暂停截图能容纳五个足够大的操作；该图处于滚动后的焦点恢复状态，不能据其顶部标题不可见推断首次打开必然裁切。

## 源码核查

读取上述九个源码，并检查 `scripts/ui/menu_theme.gd`、`plains_region_map.gd`、`windkeeper_hud.gd`、`project.godot` 与 `export_presets.cfg` 的增量。HUD 的生命、精力、射击成本、空中弹药、共鸣、武器、慢时和动作状态来自既有 ActorResource／Definition／action_resource_view；只做显示与短暂表现缓存。bind/unbind 清理连接及旧反馈。没有在所查增量发现改 Motor、伤害、资源、能力授予、地图拓扑或角色／怪物／环境生产脚本。

DemoApp 增量只有六行选择器可见性门控：按菜单状态及既有地区表现条件控制 `AvatarSelectorLayer.visible`，没有迁移其输入或改角色逻辑。地图改动为文本基线与共用面板材质，Windkeeper HUD 仅将缺字风险的 Unicode 减号改 ASCII。新标题背景和徽章分别由 IGNORE 的 TextureRect 绘制，按钮仍由原生 Control／Container 接收输入。

字体全局接入影响既有 CanvasItem，不能只用标题直接加载新字体证明全部消费者。当前 `GameTypography` 在替换旧 FontFile 字节前后调用 `clear_cache()`，持久保存三个别名强引用；这分别回应残留 glyph cache 和晚加载回退风险。实际地图中英文、HUD 世界提示及中文显示正常，未见先前方框。R2 runner 报告还记录了480个实际源中文字符无缺字；这属于覆盖样本，不能扩称全 Unicode。Fusion Pixel OFL、上游依赖许可与两个 image_gen 原图来源保留；生成图没有伪称 CC0。

继续页明确只读永久成长并返回家园，不恢复局内位置；截图的成长数值是注明的表现 fixture，不是实际写盘验收。“新手教程”仍复用操作说明页，不能宣称新增可玩教学关。

## 发现及最小修复

| ID／严重度 | 实际观察与定位 | 处理与复验 |
| --- | --- | --- |
| **R2-01／中，手机合屏未通过** | `direction/touch-hud-844x390.png`：在693×390实际画布中，位置牌约x24–374、y338–373，盖住左摇杆下半圈；摇杆中心约(61,328)，半径约49。深底板使方向反馈轮廓不完整。IGNORE 意味着此处不是已证实的输入截断，但视觉遮挡是真实像素。 | 仅在触控布局避让既有摇杆，移动／收窄位置牌或转移到空闲区域。用同窗口、实际触控覆盖层再截一张，核不盖摇杆且不挤入人物／弹道。不要为布局改输入规则。责任：UI／visual-director。 |
| **R2-02／低，地图可读性** | `direction/map.png`：当前唯一已探索竖条是暗绿，主面板是灰绿，地形边界对比偏弱，玩家亮点比已探索区域更易辨认。该图处于真实早期迷雾状态，未发现虚构路线，空白不能直接认定地图数据错误。 | 对已探索底色／轮廓做局部对比改善，在更丰富的真实探索状态核查区域与边界；不揭露未知区域，不增加假路线。责任：UI／art-director。 |
| **R2-03／低，风格精细度与文案一致性** | 正文菜单仍较多英中混排，且平整大按钮的材质细节少于铜钟徽章；手机初始 HUD 左右各占较宽一列，信息密度仍值得实际战斗评价。 | 不以加纹理、增大装饰自动处理；让用户具体评价按钮气质、资源含义和战斗视野。不是已证实功能故障，也不是用户已经接受。 |

## 已有运行证据与未验证项

本独审实际读取 `direction/assertions.json`：154 checks、0 failures；读取 `r2-direction-v2/assertions.json`：223 checks、0 failures、exit_code0。后者含原生 `Window.push_input(event,true)` 点击／滚轮、三种窗口的≥48实际像素标题目标、继续／设置／行囊等正式 DemoApp 控件；存档样本禁用持久化并明确是表现 fixture。观察项均为 passed。它们是**实现者运行、独审读取的证据**，不是本人独立执行或实体设备验证。

先前 `r2-font-cache`／helper diagnosis 的失败原报告仍在；新报告没有把旧失败改成通过。当前静态图证明所列消费者的字形恢复，不能证明所有晚加载场景、长时重入、Web FontFile cache 行为和无原生崩溃。后续冻结版本应复用项目原专项覆盖，而非反复执行不相关完整 CI。

本轮真实浏览器鼠标／DOM触屏／手柄模拟、输入不泄漏、连续快速操作、音画与动画、所有能力组合下的手机最大 HUD 密度、完整存档写盘、实体设备以及用户美术认可均未由本次独立审查证实。R1 公开网页通过不能代替 R2。完成 R2-01 后应补实际像素；对冻结源码的 Web 与最终试玩／录像交付仍按各自证据记录，不能用本静态方向 ACCEPT 代签。

## 同日最小修复增量复审

初审发出 R2-01 后，实现者修改手机位置牌及暂停菜单。独审另行实际打开：

- `build/verification/demo-ui-r2/last-direction/touch-hud-844x390.png`。
- 同目录 `pause-844x390.png`、`formal-hud.png`。
- `build/verification/demo-ui-r2/last-r2-direction/pause.png`、`pause-build.png`。

新手机 HUD 的位置牌缩为约200实际像素宽，位于左摇杆上方：约y231–266，摇杆上缘约y279，实际留出约13px，轮廓不再被底板覆盖。**R2-01 在693×390当前实机纹理中的遮挡已修复，撤销该尺寸手机合屏的 REJECT。** 这不能外推所有窄屏、高生命和多能力组合。源码仅在既有 `present_touch_menu` 内安排位置牌；短于300实际像素的画布隐藏此非战斗标签，地图仍提供位置，未改触控所有权。

新桌面暂停／行囊截图完整保留标题、暂停／行囊／禁用装备页签，将设置与操作说明并排并移除重复的 YOUR BUILD 大按钮，减少等重操作；新手机图能同时看到页签与关键操作。当前手机图仍是焦点恢复后的滚动状态，标题可在页顶访问，不据该静态图签首次展开布局。禁用装备页旁明确说明未开放，没有假反馈。

读取最新 `last-direction/assertions.json` 为 **146 checks、0 failures**，`last-r2-direction/assertions.json` 为 **223 checks、0 failures、exit_code0**。不把较早154的计数搬到移除重复操作后的新报告。上述同序九文件源码 bundle 在增量读取时为 `177d707fd9b193679c3d1ca77b5d99f6396bfbaeea807ea72a8260467cae0980`，仍为未冻结工作区。

实现者另修正 HUD 持久保存 `_chrome_theme` 以免原 `style_canvas` 换掉主题。补打开无遮罩的 `last-direction/formal-hud.png` 后，MENU 可清楚看到圆角、暖铜边与厚底边，和地图／钱包的材质一致；暂停遮罩后的图不足以判断该细节，无遮罩实际图已补足证明。R2-02／R2-03 与全部 UNVERIFIED 边界保持。
