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
