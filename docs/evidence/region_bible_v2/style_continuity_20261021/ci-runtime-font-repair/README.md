# 原124 CI失败、字体与去环修复证据

这是完整原件的无损普通Git包，不是新一轮游戏测试。**原124完整CI仍失败；修复后完整新CI待执行。** 历史收据没有重写，旧浏览器通过没有改签当前修复源码。打包者没有运行engine、改生产源码/Git、做美术或删除任何原件。

## 源版本与实际结果

| 阶段 | 精确来源与范围 | 结果/限制 |
| --- | --- | --- |
| 原正式CI | `124815766d1c9fb93224bca05fa2c9f7fe265ac5`，[run39571747310](https://github.com/zhipijun1996/gunman-rush/actions/runs/39571747310) | parallel的region原537断言有2失败，实际是两件Forest文字所需8个兼容字体字缺失；serial的terrain-family首先出现具体Stage类型依赖环，随后positive原240秒超时。不是forest80失败或80预算不足。两失败artifactZIP、完整joblog、regionlog、serialreport/coldimport/firstparsecontext全部原件收存。 |
| 原同次其他job | 原124源码；原API/jobs时刻保留 | Web42、docs29、Windows通过；不能抵销两lane失败。部分API是当时in_progress快照，如实保留，不伪造最终API。serial9项已过、terrain第10项失败，余42项及后续softwareGPU/audio未执行，不能称完整CI批准。 |
| 字体兼容修复 | 原124冻结85输入与原工具；原Noto源SHA `a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da` | 保原463字符及每字符metrics/decomposed outline，0差异；新增36到499，包含原缺8字。独立静态677检查限定ACCEPT。候选/生产字节相同。原OFL及下载OFL保留，二者仅历史一处尾空格不同，不改写。当前UnderworldUI本来用foundry_notes.otf，不把兼容guard失败误称当前正式UI可见缺字。 |
| 去环最小修复与本地原生 | 原124为base、5个明确WIP生产路径：字体/README/既有资产卡+App/helper；精确SHA由原before/after与独审绑定 | 唯一helper具体Stage依赖切断、caller保原is/as/version guard；原font537/0；原terrain--all-maps正508/0、10seed×2map共20行，负55断言/1次原intentionalfailure被正确拒绝。原预算/runner未放宽，完整22998源/Git守门稳定，5文件同时匹配root和inner原始源。仅该入口技术修复限定ACCEPT，另一个Boss静态闭环未证为原124 cause，不预先扩修。 |
| 本地四项快反馈 | 原124干净源，`20261021T084643.196128Z`完整9原件 | contract/tests/SFX-source/generated-consumers四项passed，194.624秒；它发生在后续字体/去环WIP之前，不是新源码全量回归。 |
| 旧原CI ZIP三浏览器 | 精确原124 WebZIP、原3工具、22998源/Git前后守门 | 真desktop canvas+Chromium CDP触控25/40/8通过，547.026秒。完整浏览器242件输出/截图/events/log/receipt保留；属于旧124包，不能重签5文件修复后的source，更不是实体设备/FUN或全CI验收。 |

当前森林native2仅既有有限静态覆生平台范围；整区有机大形、正常速度主观观感、音频感知、实体设备与玩家趣味性仍未完成。独立AI静态/源码审查、真实技术native/browser、用户审美与设备/FUN分账；本包不新增任何整区艺术或发布通过。

## 普通Git的原件载荷

`original-evidence.tar.xz` 是**一个完整tar流**的XZ/CRC64压缩：435成员、原文79,158,903字节，归档29,548,172字节，SHA256 `c39a4c153f0f12da614772d34800bbdb948f2531b305631d569f6046bb4055db`。完整source inventories作为原成员进入同一流，避免逐JSON单独ZIP导致重复膨胀。

`member-index.json`逐成员保原完整路径、archive相对路径、bytes/fullSHA、mode/nsmtime及分组。repo文件映射到`repo/`，原/tmp文件映射到`tmp/`，不把它们冒充已在生产树的source。所有435成员已实际解回本新目录的临时子树，逐份fullSHA/长度并逐字节对照原件；整条XZ读到EOF校验CRC64，随后原stat/SHA再次一致。只删除了本次生成的解回校验副本，未删除任何原件。`readback-verification.json`保存完整结果。

载荷含原CI失败/font计划及before全36件、root本地修复全5件、terrain全6件、字体独立诊断/审查全6件、隔离85输入/工具/候选全91件、旧交付除WebZIP外全15件、browser排除web/后全242件、四项快反馈全9件、去环首轮全16件及最终全5件；额外保原/下载OFL与已审字体元数据4件。13个原CI Gitblob源码baseline、最终2文件snapshot及diff保留，可追究具体修复；这并不宣称完整游戏源码都在本证据包内。

这些文件可直接作为quality evidence，均为原JSON逐字副本：

- `font-independent-review.json` ← 原font `candidate-review.json`，不把静态审查改签native/UI图像通过。
- `runtime-independent-review.json` ← 去环second原最终`review.json`，首报告和完整基线仍在tar内。
- `runtime-native-receipt.json` ← root原本地修复`receipt.json`，其中native范围不扩为完整release。

## 明确没有重复打进Git的原件

原WebZIP仍在`/tmp/gunman-bible-delivery/final-1248157/gunman-rush-web.zip`，297,996,606字节，实际fullSHA `4fe0514ef1e2f8d4b42d175266b4a9bafe670fd9f6afdd0b2efa724f6e668765`，与GitHub实际artifact12333121422的API digest逐字匹配。原API、下载API/到期快照及源/构建info都在tar/索引；[原artifact API](https://api.github.com/repos/zhipijun1996/gunman-rush/actions/artifacts/12333121422)。GitHub期限按原快照2026-10-28，不承诺永久下载；本小Git包不含可独立启动的完整Web游戏。

同理17,772,300字节原Noto母版没有重复拷入，原完整SHA/URL/许可文本保真，候选123,276字节与85输入和tool原日志完整可查。源URL为`https://github.com/google/fonts/tree/main/ofl/notosanssc`，不编造新许可。

root在浏览器终态后把旧web/提取物361件逐SHA迁至`/tmp/gunman-bible-delivery/served-web-1248157-preserved`；原ZIP不动。新增小原收据`web-extraction-relocation-1248157.json`逐字副本独立附在本目录/索引，未为它重开已锁tar；361提取文件不再次复制。该存储迁移不改变旧浏览器scope。

可用标准tar解包到独立检查目录：`tar -xJf original-evidence.tar.xz -C <empty-directory>`，再依member-index逐份校验。不要覆盖生产目录，亦不要把压缩/解回验证算作游戏或CI测试。
