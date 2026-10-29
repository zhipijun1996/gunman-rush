# MOBILE-UI-CLARITY-01

修复并已发布：[试玩2caa023125bd](https://zhipijun1996.github.io/gunman-rush/?v=2caa023125bd)。生产运行源4707b9ef15fa7e89b09d3e33ef8206c0b12f64af，部署分支deploy/mobile-ui-clarity-20261029，源码fix/mobile-ui-clarity-20261029；不合main。

## 原因与修正

旧Web关闭HiDPI，以手机CSS小尺寸先画世界再放大；菜单/HUD又逆物理缩放，手机上出现相对游戏画面的超大UI、文字与细像素丢细节。当前Web内部RT固定为完整1280×720，并用真实DPR backing store以nearest呈现；原生仍canvas_items。所有设备共用逻辑UI尺寸，家园重复菜单/文字与摇杆重叠已清理。没有重采样美术原图或更改音频、物理、保存。

世界前景shader使用RT局部屏幕像素，上传保护矩形改用get_stretch_transform；get_screen_transform含黑边偏移，不能直接当RT坐标。此处shader原文不改。

## 已执行证据

- [原生37／0](validation/native.json)，四窗口尺寸和真实Controls/输入回调；[原合同149／0](validation/contract.json)，保留旧检查与断言，只按用户新共享尺寸合同迁移物理屏幕最小尺寸预期。Web密度8／0见[日志](validation/density-02.log)。检查后UI生产字节未变；Foundry原重建仅更新生成资源与导出basis，见下文。
- [实际导出Web](browser/report.json)：桌面1280×720 DPR1、手机853×290 DPR2.5，真实鼠标/触屏进入Home、菜单、返回与844×390窗口调整。实测原生铜色按钮逻辑边界最大差0.6wu。第一版暗像素边界估计误把标题暗背景视为黑边，旧报告/driver保留，当前依据16:9居中画布与截图物理尺寸换算，不改按钮像素测量。
- [GPU隔离探针](mask-probe/result.json)：原生产_render_receipt及未改shader，RT1280×720、screen origin422/0、stretch1。受保护点2233cc，左右前景40594a；实际截图与构造脚本保留。明确使用白色矩形fixture，不冒充正式关卡、玩法或整屏视觉验收。
- 最终源的两份已修改UI测试也已实跑：[图鉴UI72／0及R2菜单/输入208／0](validation/remaining-native.log)，真实正式App/Controls，严格run_tests.run_engine，未见原生/script/shader错误。
- [独审](review.json)：生产零修改、九张真实Web图、限定ACCEPT。
- [公开完整包](public-download.json)：HTTP200、208691576字节、SHA256 2caa023125bd6fcf2b960dcdf5ac60a6a7abdbfeb643ef0b661f80f6a15d5a31。部署[Actions40870121582](https://github.com/zhipijun1996/gunman-rush/actions/runs/40870121582)成功，正式原loader/engine与完整资源包。
- [风格绑定](source-bindings/validation/summary.json)：原32＋10保留、当前33／11及两合同检查fresh通过，仅四个真实消费者叶重绑，PNG/shader不变。

首次import缺件、旧物理尺寸断言失败、Home原本不暂停SceneTree而专项曾误判、首次Foundry导出守门拒绝均保留在validation/。按原工具重建Foundry36development phrases／18continuous itineraries、0失败后刷新basis再成功导出，不绕过门禁。文档Harness首跑期间仍在补证据，frozen snapshot源变更而中止，保留日志，不称通过。

## 边界

Chromium SwiftShader只是桌面/手机屏幕与DPR模拟，没有荣耀60Pro实体设备。此次不签FPS改善、金币音效恢复、完整两区动态、用户审美或G5；质量awaiting-device。新包可先供用户验证UI和清晰度。公网实际模拟手机GUI也已通过：[收据](public-browser/report.json)，真实点击设定并返回、进入家园、菜单HOME关闭、844×390调整均通过，page/script/shader错误为空。最终[定向Harness](validation/harness-final/report.json)实跑docs、web-cache、web-bundle三项全fresh通过；不称完整33项docs profile或full CI通过。文档稀疏缺件已按原cloud_inputs工具恢复2730个精确HEAD输入，未改sparse规则或检查预算；任务依赖占位符曾不符合原validator，修正为规定的“—”，失败日志保留。

复现GUI：`python3 tools/verify_mobile_ui_clarity_browser.py --root-url <url> --expected-source 4707b9ef15fa7e89b09d3e33ef8206c0b12f64af --expected-build 2caa023125bd --output build/verification/<fresh-dir>`；远程代理环境追加`--proxy-from-environment`。该工具仅正常GUI输入与像素/OCR观察，不修改游戏状态。
