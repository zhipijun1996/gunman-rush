# DEMO-UI-01 · R2 用户反馈返工

2026-10-23，用户明确拒绝R1外观：“我觉得现在还是不好看”。原运行源df5207ccc920f5d48813412a27d9d72dc79510ab，原技术通过不作为美术认可。origin/main基线e9ab0e0743466b8983e34cc7de17bab1abf9d53a，继续独立feature/demo-ui-01，不合main。

本轮将真实Control、CanvasItem文字统一为Fusion Pixel 12px proportional简中家族；许可OFL及依赖原件保留。GameTypography autoload为默认Theme及三个旧FontFile运行时别名提供同一字体，并先后清除旧导入字形缓存、持续保有引用，防止旧缓存错字与晚加载回退；原字体文件与角色/敌人/环境脚本不变。Windkeeper HUD只将两个不被该字体覆盖的Unicode减号换为ASCII减号，不改数据。

标题用独立新生成的印象背景和透明DISORDER CLOCK破裂旧铜钟徽；原PNG不加工，轻微漂移/风尘可由已有减少装饰特效设定关闭。四主项为开始游戏、继续游戏（选择存档）、设定、新手教程；开发入口降为次级。所有按钮为真实可操作控件，圆角、铜边、底部厚度和焦点样式复用同一Theme。

继续游戏只选择已有单一本地成长记录并返回家园，不造多槽或中途续关。Preview禁用持久化，只诚实显示本次会话记录。新手教程先显示操作说明，可进入正式平原既有教学起段，不创建新授予或完成状态。

HUD保持正式数据与原生命周期，采用独立心槽、校准精力舱、离散弹匣和武器小徽章，避免大黑板。暂停页提供暂停/行囊真实分页；装备栏禁用并写明未开放。保留危险返回确认、原存档、取消和输入隔离规则。

共享接入供总控复核：project.godot仅字体autoload/custom_font；DemoApp._process新增6行UI可见性，将旧AvatarSelectorLayer限定于无全屏菜单的实际兼容消费者，角色表现脚本只读；export_presets仅新字体许可/来源的include_filter；assets/manifest仅注册本任务两张UI图。没有玩法/拓扑/Motor/伤害/资源/能力/存档改动。

R1断连原件已真实恢复并按逐文件SHA验证归档到docs/evidence/demo_ui_01/r1_recovered_raw.tar.gz及manifest，非摘要重建。R1原质量卡/交付说明在本目录保存历史原文。

本轮需真实专项、正常尺寸与手机合屏独审、独立Godot Web和连续MovieWriter录像。用户审美与实体触屏/手柄仍待实际评价；任何技术绿灯或AI审美意见均不代签。
