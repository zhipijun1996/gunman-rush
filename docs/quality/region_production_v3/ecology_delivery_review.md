# V3 生态交付复核：已出现新判断，整区生态仍未完成

审查者 `/root/v3_ecology_admission`，只读生产源码及既有实际证据；本文件不是新增敌人/Boss设计或完整内容准入。来源为PR67/68继承实现、V3 Root Bell V2、实际旧电影、父集成原生与新默认路径原生。原conditional审查及实际看图清单见[独立证据](../../evidence/region_production_v3/ecology_admission/README.md)。本次没有运行Godot、播放音频或代签用户/设备。

## 玩家能够观察到的收益

芦铃播种者新增的价值是**固定地面标记与可中断预告**，不是增加一种外观。已有巡逻冲刺、定向射击、俯冲、跳扑与扇形炮台分别主要限制接近/站位/穿越时机；新敌先锁定玩家脚下位置，玩家可走离已固定标记、跳过活体，或稳定站位射击，以真实HP命中中断预告。射击同时产生既有反冲，瞄准和后退余量因此属于遭遇设计。

实际movie02的27张独立观察原尺寸帧包含锁定后离开、连续6帧芽刺、连续4帧弹体运动、HP逐次下降/死亡和回程。新手绘扎根黄铜植物与芽刺已由真正EnemyActor/RootBellPresentation消费，替代早期双影与代码三角攻击表现。它没有改变PlayerMotor、武器/能量规则，也没有把敌人当作必需的钩点、开门或能量供给。

实际已有父集成native：15案例、5145物理帧、9脉冲，正常接近、phase0/30/60的步行离开/活体双向跳越、真实两次HP打断及死亡、死后穿越、完整连接与齿轮返程；1046源前后相同，日志无ERROR。随后独立核对的新`root_default_final_01`确实使用`--root-bell-default`、`default_requested=true`，仍15/5145/9且source稳定、exit0。它补充普通默认选择路径，而不是把旧explicit pilot改名成default成功。

这些证据支持“这一受约束遭遇可以产生不同的操作判断并已有真实通路”，**不支持整张平原已经拥有成熟敌人生态、所有武器/玩家行为已覆盖或普通玩家一定觉得有趣**。

## 使用率和空间边界

40个当前campaign Manifest样本只有1个advanced候选合格，intro为0/20。准入由物理/机制class决定：当前仅经过真实试跑的连续实心`double_gear`银行，满足双侧观察/撤回、无邻接扫掠/低顶冲突、非教学/营地/准备区等条件；每图最多替换一个既有lane守卫，数量和ID预算保持。具体宽度只是这次被试class，不是全游戏规则，也不是Seed白名单。

可复现root Seed为`v3-root-bell-pilot-1`、map2，实际seed为`v3-root-bell-pilot-1/plains/map_2`。电影是独立map2正式消费者入口，不证明从map1击败Boss完整通关至map2；试玩未必自然遇到该稀少候选。不能用新增1种敌人或21个实例宣称生态完成。

620px实心观察银行提供清晰的学习和反制空间，这是优点；它同时意味着新攻击与移动齿轮的耦合较弱。不能一面依赖宽阔隔离银行证明公平，一面宣称已经完成密集机关战斗组合。未试几何类不应为增加曝光率直接放宽准入。

## Boss本轮是否需要重做

源码检查表明，现有Boss已经有地区相关的真实机制：`WindkeeperDefinition`、`WindkeeperEncounter`按阶段组织地波/冲刺、平台与背铃射击、风区/旋刃、追逐及平台落击；正式提示也要求不同站位和射向，不是单纯增加HP。小Boss仍是既有鸣铃巡游机，Boss封门/暂停/死亡/奖励契约不由本轮新增敌人改写。

当前没有本轮新的Boss完整正常速度战斗审查能证明其“已经达到品质目标”，也没有可归因于新Root Bell的Boss机制失败足以支持本轮另开大重做。因此建议**本轮保留已验证Boss机制，最终执行相关原回归；下一轮凭真实战斗画面、失败位置和机制教学关系再决定是否改造**，不为了“完整区域”强制新增Boss。

Boss空间美术原图连续两次原spec失败并已停止，不能当作成功资产推广。本轮未给Boss黄金视觉或完整战斗品质PASS。现有Boss与Root的“读预告—改变站位—找射击机会”有概念联系，但普通敌人教学是否实际改善Boss学习，尚无对照玩家或完整campaign证据。

## 声音：复用与原创必须分开

真实`GameAudio`从`assets/audio/kenney/<cue>.ogg`读取CC0素材，12个受限voice、事件节流和暂停处理已存在。Root的攻击使用`bell`、真实命中中断使用`armour`，其他敌人/角色/Boss同样复用中央cue；来源与逐文件SHA见[Kenney来源](../../../assets/audio/kenney/sources.json)和[说明](../../../assets/audio/kenney/README.md)。

因此可以说“已接入既有合法声音事件”，**不能说本轮为Root原创制作完整音效家族、环境音乐或通过听觉品质审查**。历史WAV仍在仓库，但当前正式consumer用OGG，不能据旧WAV存在宣称其被使用。本审查未听音，音量平衡、预告辨识度、手机扬声器和多敌重叠仍未验证。

## 还缺哪些玩家判断与验证

- 垂直空间、移动落点、狭窄过渡中的敌压仍主要来自旧diver/hopper/sentry编排；未建立新的跨空间黄金遭遇证据，不能由Root平地银行覆盖。
- 新Root提供诱导/躲避/打断，但未实现反向利用敌人触发环境、动态目标牵引等新系统；这些不是本轮必需补齐的机制，更不能冒称已有。
- 敌人活着/死亡/失活的局部生命周期已有实际fixture反例；正式地图全部状态、自然低资源、各种当前合法单武器构筑与手机同时操作负荷尚未覆盖。不可从Pulse Lv1轨迹外推所有构筑。
- 40样本是准入覆盖，不是40个完整游玩成功。已知失败电影01在Root出现前的摆渡/飞敌处受伤停滞仍保留；电影02完成不消除旧失败。原电影02的10 ObjectDB/4资源退出错误也不由新headless干净日志洗掉。
- 金色预告在所看中性银行清晰，小绿色芽刺与草地色域相近；最终新环境正常电影的危险/落点可读性和Web实际采样仍需独立检查。新postdraw defaultmovie在本次写作时尚未完成，不能预签。
- 本次已修“连贯删grant再重放曲线也被误收”的真实验收漏洞；原27+9拒绝证明验收器更难被伪证骗过，不是36次额外原生游玩。实际shot、projectile first hit、grant、accepted recovery与event_id/epoch/tick因果仍须来自真实producer。

正式小池flag已经启用为有限review试玩候选，原子任务仍review、旧REJECT不改。原[父集成闭包与严格反例](../../evidence/region_production_v3/enemy_parent_integration/README.md)、[原电影与失败](../../evidence/region_production_v3/enemy_encounter_v2/README.md)和[默认局部复核](../../evidence/region_production_v3/ecology_admission/default_native_partial_addendum.json)各自保留准确版本与范围。最终default兼容40audit/原165、最终录像/Web、性能、听觉/设备和用户认可按实际后续结果补充，不由本文件代签。

## 下一个地区的一句启动要求需要自动加载什么

“制作荆棘森林。”应首先加载[动作设计入口](../../design/player_actions/README.md)、[regions_v0.3](../../design/player_actions/regions_v0.3.md)、武器当前覆盖、真实能力Definition与授予消费者、Visual Bible、当前生产经验和旧失败。

森林是S2的H分支：只允许已经选择的H，加基础跳跃/初始武器反冲；可选高阶挑战也不能偷偷要求W/D/U1/U2。H必须真实发射、飞行、命中合法锚点/可牵引目标、拉近、接近踢跳并处理落空，不是瞬移、钩任意背景或免费刷新空中射击。实际H技术slice不等于正式通关后已授予H或森林已开放。

系统应据此自主比较树冠连续突进、活锚点及敌人生态候选，检查敌先死/目标移走后的合法替代/撤离、真实资源与返程，再做最小黄金；不能复制Root的620px平地class、平原Boss、绿色贴图或默认授予作为森林规则。当前短Prompt路由与真实H技术片证明启动机制的一部分，尚不证明完整森林地图、敌人、Boss、美术和最终交付已经自动完成。
