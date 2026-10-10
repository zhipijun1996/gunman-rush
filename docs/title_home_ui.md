# 主标题、菜单与可操控家园交接

## 范围与已确认需求

2026-10-10用户要求提升主标题/菜单精美度，并生成给写代码的Codex接入的家园UI美术。家园必须是可操控人物的横向场景：走近不同NPC，对话打开换人物、永久升级、成就；NPC逐步解锁；场景出口开始冒险。这是新需求，优先于旧按钮家园的展示方式。

本次交付是美术资源、样式参考和实现契约。静态设计图/浏览器交互预览不代表Godot已接入、永久经济已实现或存档已持久化。工程仍使用`GUNMAN RUSH`工作名；“失序之钟”“鸣钟枪”及主角身份未确认，不作为正式标题。主背景沿用[世界锚点](world_and_story.md)和平原边缘发光花家园意象，精美度门槛见[美术品质目标](art_quality_target.md)。

## 样式与信息结构

用细腻手绘纸面/木板、旧黄铜、暖象牙与克制的青色光点，保持平原阳光、草木、机械遗迹的统一质感。红围巾作为人物焦点；金色用于选中、青色用于可交互，锁定使用低饱和与锁图标，不能只靠颜色表达状态。纹理适度，不让纸张纹路损伤正文可读性。

本次样板采用居中字标与纵向菜单，背景复用家园场景；代码端可按宽屏安全区调整为左侧菜单，但保持字标与按钮独立。主要按钮“进入家园”，次级为设置、操作说明；桌面原生才显示退出。已有三关开发快试、十关试炼、MODULE LAB、RANDOM STAGE保留在明确标注的“开发试玩”子页，不能丢失现有消费者，也不能把三关标成正式冒险。

首次进入与每次RunEnd都进入Home场景。正式冒险由出口触发出发页，展示当前人物、已生效永久基础、已开放地区与模式；平原固定首区，未实现的其他地区不开启。正式十小关/Boss10规则不变。开发快试独立标注development_only；输入Seed只用于已有开发消费者或未来正式规则授权后的配置。

家园自由行走时不常驻大菜单：顶栏只有家园名、可用永久货币/当前未接入说明、设置；靠近NPC出现姓名、功能和交互提示。上一次局只读摘要可折叠查看，不继续展示为可消费局内钱包。不能用发光花替代挑战段安全锚点。

## 固定家园布局与NPC接口

家园是固定安全场景；后期随机生成仅作用于冒险关卡，不随机移动功能NPC或出口。可增加装饰变化，但功能地标/交互可达性稳定。建议从左到右为发光花出生点、人物NPC、永久升级NPC、成就NPC、出发出口；此顺序是样片布局候选，尚非剧情/解锁顺序决定。NPC名字和身份也是候选称谓，不锁定世界主角设定。

| 稳定功能ID建议 | 功能 | 可见/锁定反馈 | 解锁后入口 |
| --- | --- | --- | --- |
| `home_character_keeper` | 换人物 | 建筑保留、NPC隐藏、封闭徽章与解锁线索 | NPC短对白→人物面板 |
| `home_upgrade_artisan` | 永久升级 | 建筑保留、NPC隐藏、封闭徽章与锁图标 | NPC短对白→升级面板 |
| `home_achievement_archivist` | 成就 | 建筑保留、NPC隐藏、封闭徽章与解锁线索 | NPC短对白→成就面板 |
| `home_adventure_exit` | 开始冒险 | 出口地标始终可辨认 | 出发确认→新Run |

`HomeNpcDefinition`候选最小数据为`npc_id/version/function_id/unlock_rule_id/display_key/portrait_asset_id/world_asset_id`；条件由Meta/实际解锁服务给出，画面不根据颜色、NPC碰撞次数或动画帧自行判定。实际接入前只实现有消费者的最小类型，不能先建全套空服务。`locked/available/busy`为功能状态，`idle/near/focused`为视觉状态，二者独立。未解锁功能禁止消费/选择；可展示“继续冒险将迎来新的伙伴”等非数值提示，正式门槛未定时不伪造“通关1次必解锁”。

当前生成的`home_background.png`为1672×941整体手绘背景，建筑已烘焙：人物帐篷约x=0.12、升级工坊约x=0.47、成就书屋约x=0.73、出口约x=0.92，走道约y=565（高度60%）。这些是视觉定位参考，不是碰撞精确坐标；实现需校准人物脚底与独立地面。锁定方案采用建筑保留、NPC不显示、封闭状态徽章叠加；尚未生成独立施工/未点灯建筑状态，不能声称该资产齐全。`title_logo.png`使用GUNMAN RUSH工作名。

已解锁NPC保持可达且不会再次锁定，除非未来显式内容规则另定。一次解锁只显示一次到访提示；去重依稳定unlock_id与Profile收据。当前无SaveService时预览切换仅演示状态，界面明确“演示解锁/当前会话”，关闭重开不声称保存。

## Godot场景和表现接口

目标Godot 4.7.2 Standard、类型化GDScript。建议按实际消费者拆分以下节点；名称为接入建议，未创建这些运行节点。

```text
DemoApp / AppCoordinator                   # 生命周期、状态、路由与输入取消
├─ TitleMenu (CanvasLayer)
│  └─ SafeArea / TitleRoot (Control)
├─ HomeScene (Node2D)                      # 固定安全场景
│  ├─ BackgroundLayers (Node2D)
│  ├─ Ground (StaticBody2D)                # 人工定义碰撞，与贴图分离
│  ├─ HomePlayer                          # 复用真实控制器与唯一PlayerMotor
│  ├─ HomeNpcs (Node2D)
│  │  └─ HomeNpc / Visual / InteractArea (Area2D)
│  ├─ AdventureExit / InteractArea (Area2D)
│  └─ CameraRig (Camera2D)
└─ HomeUi (CanvasLayer)                    # 提示、面板与焦点
   └─ SafeArea / OverlayRoot (Control)
      ├─ StatusBar / InteractionPrompt
      ├─ DialoguePanel / CharacterPanel / UpgradePanel / AchievementPanel
      ├─ DeparturePanel / SettingsPanel / HelpPanel
      └─ ConfirmationDialog / TouchHomeControls
```

UI只发局部请求，如`request_interact(npc_id)`、`request_character(character_id)`、`request_purchase(upgrade_id, quote_id, transaction_id)`、`request_departure(selection)`、`request_close`。App/现有消费者验证资格、控制输入、安排模式切换；服务回传明确result/revision，UI再更新。不要创建万能事件总线。沿用`scripts/ui/demo_menu.gd`的表现/请求边界与`scripts/demo/demo_app.gd`拥有暂停、配置应用的边界；现有`requested_start`是开发消费者请求，不能由换皮按钮直接绕过新Home。

Home不初始化临时Run钱包、敌人或奖励账本，不把玩家走进NPC区域算成Run。Home人物展示由CharacterDefinition与Meta基础派生；实际运动仍交给PlayerMotor，一物理帧最多一次`move_and_slide`，不得用UI tween或修改position控制人物。人物选择成功后在安全出生位置重新派生表现/基础，取消旧输入；换角色不授予局内物品，也不改变全局物理默认值。

## 输入所有权与状态迁移

| 状态 | 输入持有者 | 进入/退出原则 |
| --- | --- | --- |
| `TITLE` | 菜单UI | 进入家园请求由App创建Home，无Run结算 |
| `HOME_WALK` | Home InputRouter/真实Motor | 左右移动；交互通过现有上方向意图；不显示战斗瞄准控件 |
| `HOME_DIALOGUE` | 对话UI | App清旧动作与触点，再阻断Home运动意图 |
| `HOME_PANEL` | 功能UI | 稳定焦点导航；关闭返回NPC附近，旧按住动作不重放 |
| `HOME_DEPARTURE` | 出发页UI | 一次提交，等待消费者接纳；失败仍在Home |
| `RUN` / `RUN_PAUSE` | 现有Run/菜单契约 | 保留段回退、RunEnd、构筑和返回确认 |

以上为App表现状态建议，不能覆盖RunDirector正式终态/epoch。进入任一覆盖面板，失焦、断连或模式切换均由App调用Router.clear并停止aim/慢时；取消不是松手射击。UI拦截鼠标/触摸，按下打开面板的同一输入不能立即确认消费；初始焦点放非破坏性选项。关闭面板后需要新触摸/重新武装。面板覆盖安全场景时App可暂停其游戏时钟，UI使用PROCESS_MODE_ALWAYS；不可由Control直接设置全局时间倍率。

NPC触发区只提供候选，不自动打开面板。多个候选按距离与稳定ID明确排序；保持当前提示直到离开滞回范围，避免重叠闪烁。浏览器样板用E演示交互，正式接入键鼠交互沿用W/上，手柄沿用左杆上阈值/重新武装规则；UI确认/取消按现有UI映射，不擅改Run开枪或跳跃。Escape在子页回上级，再关闭覆盖回Home；Home中Escape打开设置/导航页，不误启冒险。Run返回Home保留明确放弃本局确认。

手机横屏Home使用独立左移动控件与“交互”按钮；跳跃入口是否展示沿用真实Home消费者能力决定，不作为新能力承诺。Home隐藏右瞄准杆，但不更改Run触屏布局。触点各自捕获，面板打开时全部取消；触屏提示不依赖hover。桌面隐藏虚拟摇杆。控件按安全区布局，建议最小可点击边48逻辑像素、正文20–24px、主要按钮24–28px；这些为1280×720样片尺寸建议，仍需Android真机确认。

## 三类功能面板

换人物：左侧NPC肖像/对白，右侧人物卡与基础能力摘要。当前角色有文字标记；未解锁卡展示锁图标/条件；选中仅预览，点“使用人物”才提交。服务成功后更新当前角色，失败显示原因。不能假设已有多个可玩角色；只读候选卡用“制作中”而非虚假可选。

永久升级：展示永久钱包、项目名、当前等级/上限、当前→下一阶效果与明确报价。未实现经济时显示“功能制作中”，不得启用假购买。支持“条件未满足/余额不足/已满级/提交中/失败可重试”；视觉禁用不代替服务校验。货币单位与升级价格未定，样片数字若出现必须标示示例。

成就：已完成/进行中/未开放列表，显示有来源的进度与文字条件。奖励是否存在未定，不默认给永久币；“查看成就”不自动发奖。未来明确奖励后以独立幂等claim_id处理，重复打开面板不能重复领取。秘密成就透露范围由Definition策略提供。

出发：显示“开始冒险”、人物和已开放首区平原；确认时由App用当前已提交的Meta快照建立全新RunState/BuildState。成功后卸载Home并清旧动作/回调，防止重复触摸生成两局；建立失败保留Home与选择，返回错误。死亡或大关完成回Home沿用原唯一RunEnded处理，不再额外结算一次。

## 永久消费、解锁与存档边界

升级确认不凭UI本地余额扣币。消费者重新校验profile_revision、quote_id/版本、前置、等级上限、币种余额和transaction_id；同一ProfileRevision内原子提交扣MetaCurrency、升级来源和幂等收据。重复点击/回调/重试返回原结果，不再扣款。RunCoin不可在家园消费或自动兑换。

已持久化购买必须在存储确认后声明完成；存储失败保留上一有效Profile，提示失败并允许同一transaction_id重试，不展示“已保存”。若未来消费者明确支持先内存提交/待保存，则必须显示dirty并锁定同ID重试路径，不能将未持久结果包装为永久成功。冲突报价要求刷新后重新确认，不能悄悄涨价。详细原子存储/坏档恢复策略以[家园与存档契约](home_and_save.md)为准。

PR33原美术交付时Meta只有进程内摘要；这是历史范围，并非当前运行状态。当前主开发链已实现schema2原生原子存档/Web localStorage校验、音符永久钱包和vitality真实购买，Home升级面板复用这些服务。角色选择、NPC解锁门槛、成就统计仍未实现。HTML样片的锁定切换、示例角色、等级仅是视觉交互演示，不能接作正式默认经济数据。Q012仍保留具体内容/门槛待决策，Q008等经济问题不由美术稿决定。

## 图层与素材接入要求

素材目录使用`assets/title_home/`；交付manifest列明真实文件、尺寸、alpha、source/hash、锚点及atlas region。具体数值取生成结果，不用本文虚构裁切坐标。源PNG保持原样；图集通过AtlasTexture/运行时绘制region读取。不得在游戏内将概念合屏图当全部功能的可点击底图。

| 图层/素材角色 | 接入方式 | 规则 |
| --- | --- | --- |
| 家园远景/中景 | Sprite2D/Parallax2D候选 | 统一比例；未验接缝不声称无限循环 |
| 固定地面/建筑装饰 | Sprite2D | 碰撞另定义，装饰不挡人物和可交互区域 |
| 主标题字标 | TextureRect保持比例 | GUNMAN RUSH工作名独立资源；局部透明范围不决定点击区域 |
| 按钮/面板边框 | TextureRect或经验证的StyleBoxTexture | 单独文字Label；有装饰的端头不得拉伸；九宫格内边距以manifest为准 |
| NPC/道具图集 | AtlasTexture + Sprite2D | 稳定功能ID映射；静态NPC素材不冒充已生成动作帧 |
| NPC肖像/功能图标 | TextureRect保持比例 | 非语言装饰；锁、焦点、禁用和提交中可用Godot渲染叠层 |
| 正文/数字/按钮名 | Label/RichTextLabel | 动态文字、字体fallback、本地化与对比度由引擎负责 |
| 交互提示/光效 | 独立Control/Node2D | 呼吸动画克制；减少动态选项停用非必要闪烁 |

合屏样片的标题/菜单布局供实现参考，点击区域仍由Control几何定义。背景Control使用IGNORE；按钮与面板使用STOP；提示按需PASS/IGNORE，不阻断Home移动触点。CanvasLayer次序建议场景0、Home HUD10、触控15、覆盖面板20、确认30；现有菜单layer20不随意冲突。半透明暗幕只覆盖世界，面板正文保持足够对比。

## 给实现Codex的接入与验收顺序

1. 先在独立场景接入本分支标题/按钮/面板资源，保留现有设置、帮助、暂停、构筑、返回确认与所有开发入口。
2. 接入固定Home、真实Motor和NPC候选提示；出口先连接已有合法开发Run消费者。验证人物运动/输入取消，再开放真实功能消费者。
3. 角色选择、永久升级、成就分别按已实现数据能力接入；未完成消费者保持明确制作中。解锁顺序/条件待确认后数据化，不以样片数字作默认值。
4. 依SAVE-01完成存档事务后才声明持久购买/解锁；不将四个系统一次改写。

最低验证：重叠NPC提示确定性；锁定NPC不可交易；面板打开时旧移动/瞄准/触点全部取消；关闭需新动作；重复确认只建一局/扣一次；事务失败不改余额或声称存档成功；换人物不继承上局临时构筑；RunEnd只结算一次；所有开发入口仍可达。状态检查必须有失败退出码，视觉样片检查不能替代服务测试。

1280×720与宽屏/手机安全区、中文长文本、手柄焦点、触屏拖出按钮/多指取消、人物/出口不被装饰遮挡、低端设备纹理/帧率，均需真实消费者与真机验证。本次文档完成不代表这些已验收。

## 当前代码接入（平原反馈迭代）

已选择性导入PR33四张原始PNG及真实manifest，不merge旧分支，不修改源图。`HomeScene`为固定安全场景，使用现有PlayerController/InputRouter/PlayerMotor和独立碰撞地面；射击、慢时在Home关闭。W/上方向/左杆上或手机INTERACT请求附近NPC功能；面板切换取消旧输入。已实现永久升级NPC；换人物和成就为真实“制作中”只读信息，不伪造多个角色、成就奖励或解锁数值。场景建筑保持可见，未实现服务的NPC人物不显示，提示仍说明服务未接入。

`DemoMenu.show_title()`为主标题；`show_home_navigation()`保留所有开发入口、设置和帮助；暂停、构筑、返回确认保持。`show_home_panel(function_id)`用于局部NPC功能；`requested_enter_home`与`home_panel_closed`由App接入。`DemoMenu.create_theme()`提供共享奶油纸/铜/酒红主题，`atlas_region()`保持PNG原样裁切。当前动态文字使用英语，仓库没有可打包中文字体；中文长文本显示与移动端安全区仍待真实验证，不声称中文字体已齐全。

本轮独立组件技术验证：Godot `4.7.2.stable.official.ed1daf0bf`，`timeout 90 bash tools/godot.sh --headless --path . --script tests/home_ui_tests.gd` 实际24断言/0失败/退出0；测试使用真实Motor行走、独立安全碰撞地面、邻近候选/滞回、面板清动作、重复购买请求去重、未实现功能无假消费、开发菜单/暂停/返回确认保留。加 `-- --failure-probe` 实际25断言/1失败/退出1。四张原PNG尺寸和sha256均与PR33 manifest一致。首次验证发现GamepadAdapter漏命名导致空节点访问，修复后干净重跑；不把首次带SCRIPT ERROR但退出0视为通过。App联动、触屏拖出/多指取消、手柄焦点、安全区和真实视觉仍需整体验证。
