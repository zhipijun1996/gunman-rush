# 5a9f：实际发布与验证边界

公开[build 5fd40a31c4be](https://zhipijun1996.github.io/gunman-rush/?v=5fd40a31c4be)，实际游戏源码 `5a9f4bdaf846a635eb2659080d563b865758ab87`。[选定CI39160856629](https://github.com/zhipijun1996/gunman-rush/actions/runs/39160856629) attempt1完整SUCCESS：68+18=86个gameplay/art原检查及严格同源汇总，Web、Windows、deploy、verify_public通过，Android跳过。两份c5d841fd文档CI也实际成功，原5a9f PR docs因任务记录glob漏覆盖而失败，修正与独审见[范围修复](../scope_record_fix01/README.md)。

[官方日志派生核对](ci-results.json)逐原fresh/pass顺序绑定86项；原forest-depth-region600秒上限未改，stdout开始至通过586.179秒（不是inner native duration）。此前本机600.135秒超时及61+19分组覆盖原件保留，新CI不重写旧失败。独立审查见[CI/首轮GUI](final-delivery-review.md)，最终20项复验见[后续独审](final-delivery-followup02.md)。原API、官方完整stdout、公开核验、GUI原报告与选定截图在[selected-release-originals.zip](selected-release-originals.zip)，[逐成员库存](inventory.json)验证全部CRC/SHA。

公开PCK 90,357,852字节，全SHA `5fd40a31c4be5282534775dc3026007f8dbbcfb964f5363c07266b52cb590de1`；本机原verify_published_build与GitHub verify_public都通过。原GUI01实际11/20后失败：鼠标平原map1的MENU文字未识别，原图文字清楚。仅新增一个更贴合真实HUD的归一化OCR窗口，保留原全部窗口、严格MENU全文匹配、实际文字中心点击、八案例、身份/布局断言和480秒预算；原五种负例均拒，限定[独审](menu-roi-review.md)。原47文件未覆盖。

GUI02修后原完整CLI实际PASS20/20、八个touch/mouse入口、errors0、16实际App事件，森林两图v11/H-only与正确Boss资源均确认，真实进入/暂停/恢复通过。源绑定见[browser-roi-source-binding.json](browser-roi-source-binding.json)：修补是构建后的浏览器采证工具变化，不冒称它已包含在5a9f Web包；当前游戏目录/project与5a9f仍逐字节相同，不能说整个2096含tools库存全相同。原生两快线影片仍绑定原实际库存，不伪造新片。

原Azure artifact ZIP受环境proxy403阻断，零字节失败不当ZIP通过；API中的36c6…为声明digest，未独立实读验证。本次未执行准确CI ZIP的72项浏览器套件，旧H的72/72不移签。原publisher checkpoint保持waiting_ci、CI completed/success、live_verified=false、permission_or_policy错误；部署与独立公开PCK/GUI成功不能改写publisher为verified。[脱敏保管说明](redaction-custody.json)只去除临时签名重定向URL，原私有build字节/SHA保留。

[两图实际地形与快线轨迹总览](two-map-physical-overview.png)来自原捕获Manifest，Boss排除、同尺度，不代全部探索或美术图。整个内容仍REVISE/in_progress：摆荚正式接锚收益、QueenH核心价值、广泛探索/共享恢复容错、巨木轮廓和荆棘宿主、真人初见趣味/音频/实体设备及商业品质均未认证。20项GUI不是整区游玩、自然奖励/下一地区GUI或真机认可。

最终干净副本文档复验首轮漏带已提交scope_record_fix01目录而断链；补齐原文件后原check_docs通过，两次原日志同包保留。不是修改检查器或创建虚假占位链接。
