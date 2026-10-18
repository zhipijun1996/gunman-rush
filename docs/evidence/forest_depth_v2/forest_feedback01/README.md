# FOREST-FEEDBACK-01：扩大森林与连续空中动作候选

基线 `d3ba6b57ae0315f6c13573a9f303b9b9f5314b8e`，分支 `feature/thorn-forest-depth`。所有本轮运行绑定该HEAD上的明确源库存，不把未提交覆盖说成基线原字节。当前布局 `forest-expedition-airborne-v11`；旧v10冻结producer与旧存档重建保持。

## 实际变化

- 排除Boss地形后，20个固定Seed/map组合实际支持面横跨5630px，旧1330–2510px。河岸→西空心巨木→五连桥→倒木→树冠与下根回路共享空间，不计背景与空bounds。
- 连续空中HH、RH、四连和五连使用原H231px、原身体与单武器两空枪。最后多余第六钩经反例淘汰；每一H实际目标逐步绑定，接错另一合法环仍拒绝。
- 七种行为池新增前向盾甲虫和摆荚，每图14–16实例（旧3–5）。方向性甲虫已在真实遭遇通过绕背/射击/返回；摆荚的代表性接锚收益仍未证，不能只靠数量签生态深度。
- 每块平台显式材质、结构归属、表面用途；真实洞口、倒木横纹、树皮纵纹、根土层及危险朝向由正式绘制消费。当前仍灰盒读图原型，完整美术不在本轮。

## 原件与方法

[黄金、敌人与修订原件ZIP](golden-enemy-and-revisions.zip)及[逐成员库存](golden-enemy-inventory.json)保留失败、误接锚撤回、有限读者修正、真实输入战斗与独审。早期失败不因后来通过而覆盖。mission仅为规划，不是自主production-loop执行成功。

[注册air9原件ZIP](registered-air9.zip)及[库存](registered-air9-inventory.json)包含现有Harness新增的九例实际运行：四种链正例与五种删动作/普通解对照；不减少原85项检查，不修改原预算。内项通过不代父Harness通过。敌人native03原35检查通过，不代真人趣味。

固定80同源分组覆盖及原600秒失败见[独立审计](corpus80/README.md)。原raw未裁剪，严格原validate全80通过；原Harness只完成61便超时，剩19用原CLI五组完成，绝不签完整原check通过。

## 仍未通过

摆荚在代表性路线的实际H收益（FF-R06）、广泛Seed的有效决策/遭遇与重复劳动质量、共享恢复区全面误操作容错、女王H核心体验、完整音频、人类初见手感、Android/iPhone/实体手柄及商业品质。不能用像素可读、自动运动通过或数量替代这些判断。父任务与本轮均保持in_progress／REVISE。

本轮原速影片、独立像素结论、最终同提交CI与准确公开build将分别追加实际结果；未有原件的项目继续未验证。

## 原速画面与最终局部检查

[第一张西林快线原速27.1667秒](movies/map1-fast.mp4)、[第二张根下快线原速31秒](movies/map2-fast.mp4)均由真实正式App GL/60fps录制，原AVI分别1630与1860帧，原读取器运动/资源检查及独立解码对齐通过；MP4保持原速，绑定见[元数据](movies/metadata.json)。精确关键帧索引同目录可复查。长map2/growth录制240秒原cap超时，原receipt/日志与完整影片收据同存[原件ZIP](movie-and-final-contract-raw.zip)和[库存](movie-and-contract-inventory.json)，不能称完整growth片。

新版最终结构合同200/0；调试地图1/2直接进入与生命周期原生52/0通过，[原日志](debug-final-native.log)。干净运行副本包含真实文档/preview后，原check_docs通过[链接](clean-check-docs.log)。根工作区check_docs扫描旧ignored build快照报历史断链，不能冒充新版源通过；首次干净副本缺preview的运行失败也不冒签。后续完整docs Harness曾在无checkout副本的Git源指纹阶段30秒超时，另次定向debug Harness因验证lane与冻结快照不同在引擎前失败，见[失败原件](validation-failures.zip)；direct52不改签该Harness。最终准确提交CI仍需执行。

独立实际像素/时序审查：[地图1](reviews/movie-pixels09-README.md)、[地图2与总评](reviews/movie-pixels10-README.md)。两图共28张原尺寸关键帧、27+31个每秒序列点结合完整实际轨迹核对；有限认可所看锚点、身体、绳索、宽落岸及甲虫预告/绕背可读。不是全帧实时播放或听音，不签真人认可。悬空荆棘条、矩形巨木与未消费摆荚明确REVISE；未录完整growth/Boss片，原父Boss影片不能冒作新版地图片。

## 最新实际发布（覆盖上方待发布段）

[公开试玩 build5fd40a31c4be](https://zhipijun1996.github.io/gunman-rush/?v=5fd40a31c4be)，游戏源码5a9f4bda。[完整发布证据与边界](release01/README.md)：CI86项同源汇总/Web/Windows/部署/公开PCK均通过，GUI02实际20/20、八个触屏/鼠标入口，森林两图实际v11。原GUI01的11/20后MENU OCR失败、原local600/growth录像240失败仍保留；仅采证工具新增严格文字OCR窗口，原五种负例拒绝，不重建游戏。Azure CI ZIP下载403、publisher未verified及未跑原包72也不改签。默认v11可通过 DEBUG / SELECT REGION + MAP 选择森林MAP1/2直接进入。整体REVISE/in_progress和上方体验缺口不变。
