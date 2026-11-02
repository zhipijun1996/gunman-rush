# 旧地图内容检查退出默认 CI：第一批只读方案

用户已明确授权旧地图内部关卡验证退出默认 CI，未来更换地图。该指令覆盖过去“185必须完整保留在默认”的约束；不授权删除原测试/历史入口、松动预算或把旧失败改为通过。森林 timing/P12 优化已停止，诊断文件保留且未运行。

第一批14项清单和每项证据见 `plan.json.phase1_retire_ids`、`checks.json`。只从 docs/core/gameplay/art/web/full 六个默认 profiles 删除这些 ID，保剩余原序；现有 legacy-compat 原16项前缀后追加14项，复用原 profile 机制。所有 checks 定义（命令、inputs、marker、预算、serial、artifact）完整保留。新默认 full 为 **171＝92 parallel＋79 serial**；这是新范围，不是旧185通过。

默认退出：v13/v15生成矩阵、旧Foundry体验golden、三种旧plains空间/模块golden、显式历史H-only路线、旧80整图矩阵、具体旧竖向捷径/该路线返回、v15四个指定connection/backbranch路径和F08整图journey。物理参与旧路线的执行不等于该检查就是通用物理单元；退休的是特定旧几何可达/内容承诺，共用Motor/战斗/资源本体检查仍留。

`checks.json` 为全部当前注册218项逐行提供命令、profile、留/退决定和证据等级。保守保留的非地图检查仅根据命令领域分类，**没有声称218个源码全部逐行复审**。候选14及混合边界读取了真实wrapper/runner，不能据名称批量删forest。

## 自动调度不会加回的精确边界

- `harness.py:57 select_profiles` 的 auto 只产生 docs/art/gameplay/web；必须同步六默认 profiles，不能只改full。投影后 full 仍等于四profile并集。
- `production_plan.py:make_plan` 的未知/共享边界沿新full；非full domain清单可能单独加check，已实查 `config/production_impact.json` 当前所有 development/integration 数组：**这14项引用为零**。因此这一批 config 不需改；不能为“同步”凭空改空字段。若以后退役 ai-level-pilot 等，才须同步确切domain（当前 ai_level_pilot dev/int确实会加该项，本批保留）。
- 既有手动feedback/legacy profile及显式 `--check` 可继续选择这些checks，这是保留历史入口，不是默认漏退。default CI只用原默认profile/full。不创建新框架、替代注册表或假stub。

## 混合检查先留

`region` 的15套含实际掉落/生命周期/物理机关/商店库存/campaign/死亡tie；`generated-consumers` 含Home/settings/Meta/角色/表现/物理；`root-bell-spaces` 含40旧布局之外的版本存档/三版本RunManifest/掉落反例。它们不能整项退休。`plan.json.mixed_checks` 指出后续可从原wrapper有限分组选出的旧内容叶，不在本批静默减少suite。

同样保留 `level-plan`、`run-session`、`enemy-region-state`、Factory/历史revision/PCK、当前registry未知版本拒绝、App恢复、hazard几何到damage的正确适配、Boss/怪物、短H能力实际正负例、camera、拾取cache、Reader、音频与资源来源守门。`region-bible-tests` 当前depth1缺历史Git原件的问题属于资源历史指纹验证装配，**不能借地图退役掩掉**。

## 如实记录联合覆盖差异

退休80路线包含cache实际鼠标press/release、至少5个暂停帧中support/position/motion_steps固定和duplicate Interact的联合义务。现有 `underworld-world-objects→chest_art_runner` 保双区claim/拒绝/ledger/reload与W暂停恢复；`audio-feedback` 保三流重复领取不重放声音；`core`保死亡优先；Reader/App检查仍在。它们**尚未证明完全等价替代该联合观察**。建议后续在既有真实cache消费者中补该有限组合，而不重建旧地图路线矩阵。新范围清单必须标出旧route+奖励组合退出；不能声称旧80功能全部转移或passed。第一批可据用户授权先退出旧路线，不以此保留80阻碍任务。

## 实施及验证要求

保留 C59 原profiles文件/Git SHA及原remote失败，测试中把当前185前缀断言迁为C59原向量经精确14元素集合投影，保历史168…185记录含义。继续保 full-union/web-build-before-bundle/合法check/原inputs/预算/原legacy前缀的守门。新CI需要新source/newscope收据；C59原森林57通过/23无结果仍整体超时失败。不要把原失败档案计入新171通过。

本目录只含计划、证据和可复算分类脚本。未修改主树、引擎、注册表或正在运行的CI。
