# 实际单房优先的美术Skill修正

本轮按用户明确要求修改Skill：先完成一间实际房间里地形、平台、建筑与角色共同成立的画面，再从成品提炼复用。区域套件继续视为待验证假设，不作为强制生产规则。本轮交付为规则与引用修正，没有制作新的房间或素材，也不把文字调整视为美术方法已验证。

分支codex/depth-lab；本轮基线d0c072abba5f7ec34bc7badb79cf5877eb185b24。该提交保留前次三几何实验，其技术复用有局部证据，整体美术自审未通过，用户也明确否定当前方案。先前将套件生产方法提前固化的35339eb／15300cc／6094322可由Git追溯，本轮直接修正文，不追加第二套流程。

## 当前规则与写集

主入口为.agents/skills/godot-room-art/SKILL.md。整房制作默认以实际可装载房间为单位，在真实相机和角色尺度下共同制作地形、平台、建筑；先看静止合屏，再看整房、沿途机位和受影响动作。代表结构、固定机位与抽象夹具只证明其实际范围，不能关闭整房任务。

本房整体成立后才按需提炼材质、接头、构件与表现配置。区域套件是可选实验，允许失败后保留单房定制或放弃提炼；不预设普通房全部套件化、地标才可定制，不默认要求横向／竖井／宽厅配额。已有有效素材仍可直接选用，实际任务明确研究复用时仍验证真实候选、目标空间与成本。授权整区制作仍完成全部房间及串联检查，不以单房或套件签收整区。

保留已有可用约束：引擎实帧／相机／角色尺度前置、Tile拓扑与材质画法分开、独立素材完整轮廓与后方覆盖、原样切分与再次生成的区别、实际灯光／水面职责、正式控制器复验、实例分类和来源追溯。引擎约束只帮助减少转译失真，不保证画面好看。

本轮共21份文本文件，集中于上述生产顺序与候选状态：

- 主Skill及6份引用：regional-kit-production、engine-first-2d、quality-and-reuse、expansion-workflow、asset-contract、style-and-assembly。regional-kit-production保留路径，正文改为“从成品提炼复用：可选实验”。
- 7个直接调用Skill仅修相关段落：scene-composer、art-director、godot-recoil-level-design、level-module-creator、region-generator、region-creative-director、game-quality-gate。
- 5份同步文档：Visual Bible的生产与复用段、world_presentation、content_pipeline、docs索引与current_state对应条目；删除与现行顺序相反的强制表述。
- 管理记录：任务表原行及本交接。

AGENTS.md、其余Skill、代码、配置、素材和正式房间未在本轮改动。未加入额外审批、强制独审、房型配额或新的运行时库／房间schema；现有WorldRoomDocument、WorldElementCatalog与单层members协议继续持有实例化，不能把方法文本当作新增代码能力。

## 检查与方法包

按四种入口走读现行文本：实际单房制作优先完成本房；使用已有有效素材不必先做新套件；显式复用实验保留跨目标验证与失败出口；授权整区仍完成逐房及串联范围。此项是文字一致性自审，不是新的游戏或美术实测。

python3 tools/check_docs.py通过；python3 tools/check_quality.py通过14项核心Skill／模板／当前记录静态检查；python3 tests/test_context_navigation.py的5项通过；git diff --check通过。日志和本轮差异在build/room-first-skill。没有运行游戏／重拍实验，也不借前次CI宣称本轮画面通过。

重新导出仓库主美术26文件与关卡7文件的方法包：build/room-first-skill/godot-room-art-room-first.zip及godot-recoil-level-design-room-first.zip（另有tar.gz）；归档身份、源码提交、每份源文件哈希与实际包内字节核对见packages.json。它们不包含完整项目素材，也不等价于原云端完整素材包。旧build/art-method-review归档仍对应35339eb，不能当作本轮修正版。

## 云端范围

直接读取了云端godot-room-art当前主文本（skill://user/6aedc27a90608191b8024e564e73d6d2/godot-room-art/SKILL.md）。该版本尚无仓库引入的“区域套件先行”规则，但也尚未包含本轮单房优先修正；保留旧素材／边界等表述，不能认为仓库与云端已同步。

当前skill://目录接口为读取／列举，未提供该个人云端包的写入接口；Notion的技能页是另一类对象，不能冒充该包更新。实际修改仅在项目AGENTS指定的仓库入口，云端未改写。本轮另交修正版方法包，未声称已替换云端。

## 前次实验的证据与限制

前次三几何实验源码为d0c072a：只生成一次完整拱廊，派生三张原生纹理，在横通道、竖井、宽厅复用；各有96帧／12fps镜头巡查，另有正式PlayerMotor／PlayerController、UnderworldPlayer与WorldCamera的96帧左岸往返。只支持具体构件引用、有限镜头和岸段运动，不证明实际整房、编辑器接入、完整路线或区域量产。

其失败包括重复构图、平台与拱廊画法不一致、结构接续和竖井固定水天线不合场所；减少中景与统一明暗改善了可读性，仍未让整体成立。生成也未精确遵守轮廓：柱约90px而非64px，洞宽约454px而非512px。旧固定组画强行单独移动分区会出现缺失后方，平移镜头也暴露画幅边界。

媒体和证据保留在build/kit-reuse：comparison.png、ablation.png、control-comparison.png、tour-strip.png，三房型depth原始实帧与各8秒视频、controller.mp4、review.zip、capture／controller／evidence.json。源图、提示词、参考、裁切与哈希跟踪在assets/kit_reuse。前次81文件冻结记录只绑定当时实验；本轮用户授权修改规范后，不把旧freeze.json继续当作当前规范必须不变的断言。重现旧冻结检查须在d0c072a隔离工作树恢复其源与清单，不以新规则重写旧实验结论。

更早engine_first_2d的921,600像素回拼和效果证据仍只支持原坐标固定画面；其相对改善反馈不扩大为整房或量产认可。static_orchard和art_rule_trial的实际拼装此前被否决，不作正向基准。

地形／统一实例能力仍依赖开放PR156（codex/terrain-material-system→main）；本分支已有实现不等于main或公开游戏已接入。本轮没有合并／发布。原私有观看页仍是旧成功版本，不含这些新实验；既有部署失败未定位根因，本轮没有盲目重试。

## 下一动作

选一个现有实际房间，在真实装载、角色尺度和正常镜头里共同校准地形、平台与建筑，先交完整合屏和沿途结果。当前任务只修Skill，不将此下一制作动作写成已完成；不继续把同一拱廊套更多夹具或预先扩充区域资产族。
