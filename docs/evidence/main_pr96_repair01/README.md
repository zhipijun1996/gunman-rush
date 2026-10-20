## 最终候选 W7–W9（尚未合main/发布）

运行源 `169ef171fee3f70911847fb2c2890351ee3468bb`。原完整6b CI失败保留；已完成实际场景驾驶修复、严格双消费者存档检查、森林剩余挂点宿主和旧八房间退休。新完整CI仍待实际终态。

- [精确6b完整本机证明及其范围](verification-W6/README.md)：原80、policy600、电影、本地Web/GUI，不重绑后续源码。
- [W7原CI失败、实际旧源与原完整修复证据](compat-W7/README.md)：真实176项/8案例、共享120秒、负例和严格退出；错误因果已撤回。
- [W8实际果实宿主和限定构图](../forest_fruit_routes04/hosts-W8/README.md)，唯一提示词的原始失败/新可见图及24段证据另存tinyhint-W8。
- [W9原36/18和54回放56113帧等值](final-W9/README.md)。

各原始收据保留实际执行HEAD与dirty状态，commit-source映射只证明列明源码字节相同，不能冒称后来HEAD重新运行。独审原件在review；全CI、用户审美/FUN和实体设备分开验收。下文为历史时点。

---

# MAIN-PR96-REPAIR-01：主线失败修复与 PR96 整合

原 main：`dbc6ba081321637a3eef71979ecf2cf564eb6064`；输入 PR96：`2fcddc0eaca0d5f15fc0429cde2f29f98c103e0b`。本地三方合并提交：`e7286da1`，未冒称已合入远端 main。

用户授权修复主线失败、整合 PR96，并修正森林起跳镜头和钩索目标的空间问题。森林布局工作另见 FOREST-FRUIT-ROUTES-04，不能把 PR96 原平原专项通过外推为本轮森林通过。

## 原失败与整合取舍

[原 CI 摘要](baseline-ci.json)来自 GitHub 原始 run/job 日志。Home UI 本地同样复现：功能 27/0，但 297 ObjectDB 对象、208 资源泄漏，严格包装器真实退出 1。局部功能成功不冲销退出失败。

合并保留主线森林 `bind_duel`、Boss 恢复和真实物理接触记录，同时接入 PR96 的伤害反馈、跨层落地、连续可伤 Boss、开门/箱体和家园。冲突按实际消费者合并：

- Windkeeper 的接触底盘只在对应 Encounter 使用；森林仍保留完整实体接触尺寸。
- 环境接触保留主线当前帧物理接触证据，并追加 PR96 真实下层落地判断。
- Underworld 箱体/机关表现与显式旧画风候选分流，不能让新版每帧更新覆盖候选消费者。
- Foundry 旧批次不混用不同源码的回放；先保留 main 批次，冻结新源码后按原数量重建和验证。
- 主线与 PR96 的 Harness 检查按 ID 合并，未删除原检查；PR96 原生日志/TSV 的已有空白保持原字节，不改历史证据追求格式检查通过。

## 开发中的根因与边界

家园旧人物重新显示来自 AvatarPresentation 对身体显示的重复所有权；第二图 Boss 失败来自测试只改旧 stage_index、未进入实际 region_map_index=2 的消费者。

Home UI 增加真实 WeakRef 释放检查后证明 Home/Menu 节点已释放，但资源仍泄漏，故“多等几帧”不是根因。已定位 UnderworldActors 安装器与表现类的脚本循环依赖，以及需实际验证的静态缓存生命周期。拆环后的局部减少仍不等于完全修复；最终数字以最新真实日志为准。

PR96 首次整合的森林入口暴露静态危险矩形与元数据不同步：森林自建危险但继承的 records 遍历空模块。修复必须提供等长、同序真实森林记录，不能略过荆棘或套用平原坠落豁免。

[镜头设计与功能证据范围](../../design/forest_camera_stability.md)。最终新鲜回归、正常速度画面、独立审查和远端 CI 状态将追加在本目录；现阶段仍 in_progress，不签完整交付、真人或设备验收。

## 补充开发回归（非最终整源发布证明）

- 正式 DemoApp TITLE→HOME 测试保留原 27 项业务断言并增加所有者释放，为 28/0；设置实际 App 14/0；Home→Forest→Home 角色所有权 25/0，三者严格退出干净。原独立拼装 Home+Menu 的脚本缓存保留问题保存为 fixture/compiler-cache 边界，不声称任意拼装已修复。
- 原 formal-terrain 20 个两图消费者实际 40395/0。第二图使用真正的 region_map_index/debug map2 入口；断桥仍要求原切口/solids/实例断言，只在有界 8 process 帧内观察真正 geometry_changed 而不主动刷新。
- Home terraces 正式消费 180/0。完整 generated-consumers 和最终 frozen profiles 仍待执行。
- 第一次 docs Harness 因验证期间新增证据文件，原 source guard 正确拒绝为 source changed；不能以 stdout 的单项 docs PASS 冒充整轮通过，最终冻结后重跑。

## 冻结源与远端评审入口

实现 W1：`2cd7fa05356c1b8e537b624329cbb4ee0b65ef66`。后续 `28fb95b1` 仅绑定实际独审和质量记录，游戏/测试/工具/资源字节没有改变。PR96 已普通快进推回原分支，并改以 main 为目标；本轮不强推、不另留含糊的未整合原草稿。GitHub [PR96](https://github.com/zhipijun1996/gunman-rush/pull/96) 与对应 Actions 是远端检查/合并真实状态入口，本记录不以启动检查代替成功。

[W1 独立代码审查](review/W1_code_review.json)接受代码与敏感测试变更保护，明确不预签原80、聚合CI、影片或用户设备；[HomeUI负例审查](review/W1_home_ui_rejection_review.json)确认第29项故意失败造成真实exit1，原28项业务/释放检查先通过，严格拒绝保留。原Foundry按base24/double_jump6/air_chain6重建，36短语/18路线、三profile failures0，export basis `1f5d502c905d8b2df21c41cf26dda761c8ae8314f5f4406703c6b58e278ad90a`，未混用旧批次。

## W2 检查器修复及最终局部结果

完整docs profile真实停在原`objects.no_grey_claimed`：它以全文件禁串误拒显式旧画风候选。W2 `50c9ed89e5cf632d8e2a58db03f83df8fb573589`仅修改两个Python checker/test文件，游戏/资源与全部Godot测试均保持W1字节。有限适配器要求capture_state内完整、唯一、精确的legacy分支及正式opened-pose分派；其余直接/复合alpha写入拒绝。独审实际发现并退回初版*=、+=漏口，修后125tests/0（原116 AST不变+新增9）、Home wrapper36/0。原失败、初轮拒绝和最终原日志见[guard-W2](guard-W2/README.md)，[独审](review/W2_guard_review.json)。

W1正式全generated 33/33/native exit0和core5680/0原件已精选至[runtime-W1](runtime-W1/README.md)，其中原HEAD-only外层metadata guard的exit1原样保留，另以逐runtime Git tree相等核实docs-only变化，未篡改原driver退出码。W2不冒称与W1所有工具同源。

W2当前森林合同20seed/map4215/0，版本schema6实际24case完整历史22+新2；实际默认v14高返路线电影24leg/0、2241帧60fps=37.35秒、186.21秒<原240cap、source stable与严格exit0，见[完整局部原件与影片](../forest_fruit_routes04/final-W2/README.md)。独审实际看17帧接受限定起跳/落地纵向连续性和长链跟随，未完整播放/听音/验用户设备，也不称所有目标始终完整入镜或全森林美感完成。完整新HEAD原80、fresh全CI和准确Web发布仍由后续实际收据决定。

## W3/W4 最终默认入口与严格菜单退出

最终验证源 `7a58c819de52bba68594b406c07b2a940b2c5a8f`。W3兼容/截钩对照与失败保留见[compat-W3](compat-W3/README.md)，七入口旧版精确选项保留、默认指向v14；map2高返原失败430帧与旧v13完全一致，原预算内合法等待后两版各29/29。默认debug52/0、aim6leg/3hold通过。W4只更新正式App拥有的触屏菜单fixture，原43业务+释放1，原完整wrapper严格73/0、56/0、44/0，负例45/1真实拒绝，见[compat-W4](compat-W4/README.md)和[独审](review/W4_menu_fixture_review.json)。生产/资源与W1相同，W2/W3/W4改变各自明确checker/driver/fixture，不能把旧电影重绑为新driver摄录。原固定80当前执行，最终fresh docs、完整CI、main合并与准确Web仍待实际终态。


## W5 与旧八房间退休进行中

W5 测试/工具源码 `54eacfd811fe538d79d374393f10754f1efdc94b`，原CI三job、固定80实际失败和后续有限修复见[compat-W5](compat-W5/README.md)。原80执行18/失败1、后续62诊断失败3，不能拼成整轮通过；五项局部27-leg控制通过，最终整源80仍待。完整policy旧mask候选162秒失败保留为REWORK，最终恢复真实威胁调度的三项对照不代完整600入口。

用户追加授权删除不需要的旧特性（如8房间），[原话](user_cleanup_request.txt)。W6正在移除菜单旧入口、旧专用生成链与专属回归，保留现行两图、历史版本pin、quick3、Random Stage、Foundry和混合套件里的物理/战斗/镜头断言。退休前后60地图/10随机流、46真实App case已完成限定等值比较；旧world入口原有typed-empty数组崩溃独立修复并重新建立退休前基线，失败原件保留。完整保留消费者、独立审查和精确源码以W6后续收据为准。本节不是最终完成或新Web已发布声明。


## W6退休完成，最终整源入口待执行

源`c77f920bd8c31ce7640b6db44fb049efc863370b`，111路径=55清理+56来源更新。原八房专用链与两个旧房间CLI已退休，[清理清单、原数量回归与前后等值原件](cleanup-W6/README.md)，[独立审查](review/W6_legacy_retirement_review.json)。原core5681/0、完整退休后26套、UI243/0、style20/16/3CLI及world0/1实际严格通过；不把26签成旧33。最终600策略、80固定森林、fresh docs/CI、main及准确Web尚待实际执行。
