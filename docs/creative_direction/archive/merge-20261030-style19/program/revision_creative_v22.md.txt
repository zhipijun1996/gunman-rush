# 程序重构：style-v19／creative-v22 技术绑定迁移

本次仅对授权的怪物程序重构做版本化技术影响分析与重绑。两区 Bible、用户原话、方向内容、共享32px／32wu、1wu／nearest、既有PNG／配置／shader与预算均保持原结论；新版本不代表新美术、玩家、听审、设备或G5通过。

当前 style19 保持原81项 role／path／顺序，仅重绑 `scripts/demo/demo_app.gd`、`scripts/demo/plains_region_stage.gd`、`scripts/demo/thorn_forest_region_stage.gd` 三个实际入口脚本的SHA。另78项整行精确相等，无新增全局美术引用。重构新增的内部程序叶通过真实入口与原生结构测试验证，不扩大共享画风注册清单。

原 [style18](bibles/style-continuity-20261028-v18-chest-art.json) 字节不改；原 creative21 的 registry、两区方向和三脚本精确旧字节冻结于 [历史清单](archive/creative-v21/manifest.json)。旧脚本原始SHA来自提交 `45e98dbbf38d906dc5eae9686dc9ee5ee6a99acc`，只作为历史输入，不作为当前运行证据。所有历史失败与来源保留。

原32＋10方法、旧SHA、版本拒绝、漂移／恢复和负例保留。历史比较明确读取冻结21／18，当前测试追加81／3／78差异及旧21拒绝；不刷新旧hash获取通过。原30／60秒预算及region-bible-tests的294项输入顺序前缀不变，只追加实际读取的新style和7份历史输入至302项。测试迁移须独立审核；纯检查结果与原生结果、实机影片、视觉及用户认可分别记录。

新增 `enemy-structure-native` 由既有 `gameplay`／`art`／`full` 三profile末尾接入，串行执行，300秒外层上界包含原import90秒和native180秒，禁止缓存。有限运行输入覆盖真实程序／场景／资源／素材／配置／shader及精确工具／测试入口，不扩大到历史文档包。它验证原生结构合同，不签画面或全量CI。

最终绑定须在root确认三入口源码冻结后生成。当前源的实际检查结果和独审结论以本次工作线证据为准，不能继承旧版本的通过。

## 同一未发布19／22：Boss恢复完成通知（bind02）

DemoApp在全部Boss绑定完成、以及生成Boss的phase／position恢复完成后分别通知统一表现绑定同步。相对bind01仅DemoApp一叶SHA更新，其余80项引用整行一致，Plains／Forest入口字节不变；相对原style18仍仅3／78差异。原bind01四JSON与精确旧App源码保留于[本轮原件](archive/creative-v22/before-boss-restore-notification/manifest.json)，旧四check日志保留原源，不能签此次改动。

原32／10方法继续保留，追加bind01身份／1与80差异／旧22拒绝。region-bible-tests保留302项前缀，追加实际读取6件历史输入至308；原预算不变。技术验证和专项独审之外的美术、玩法、音频听感、设备和用户结论保持原界限。
