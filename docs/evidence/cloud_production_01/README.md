# CLOUD-PRODUCTION-01 / CLOUD-PREVIEW-01 实际交付

运行源 `6ca72efb1cbdb38cf83ae91c097d192a35403ccd`；基线 `74d8a06b42cb2bc2c5023f1bfe1a4fbc4b163074`。源码分支 `chore/cloud-production-system`，不合main。本轮不批量制作内容；仅增加显式开发入口及banner/menu按钮。

- [独立真实Godot Preview](https://zhipijun1996.github.io/gunman-rush-previews/previews/CLOUD-PRODUCTION-01/6ca72efb1cbdb38cf83ae91c097d192a35403ccd/adee7889f8a9/)，build `adee7889f8a9`，Seed `cloud-review-01`，直达ActionStudio；FULL GAME / MENU返回实际完整菜单。开发入口与重建菜单的DemoApp均禁meta持久化，不认证成长保存。
- [24秒真实MP4对照](https://zhipijun1996.github.io/gunman-rush-previews/deliveries/CLOUD-PRODUCTION-01/6ca72efb1cbdb38cf83ae91c097d192a35403ccd/3e6efc33b970/comparison.mp4)；[before](https://zhipijun1996.github.io/gunman-rush-previews/deliveries/CLOUD-PRODUCTION-01/6ca72efb1cbdb38cf83ae91c097d192a35403ccd/3e6efc33b970/before.mp4)／[after](https://zhipijun1996.github.io/gunman-rush-previews/deliveries/CLOUD-PRODUCTION-01/6ca72efb1cbdb38cf83ae91c097d192a35403ccd/3e6efc33b970/after.mp4)／[原录制报告](https://zhipijun1996.github.io/gunman-rush-previews/deliveries/CLOUD-PRODUCTION-01/6ca72efb1cbdb38cf83ae91c097d192a35403ccd/3e6efc33b970/report.json)。公开静态文件，无Actions登录／保留期限制；地址仍受托管仓库存续控制。
- 同源UI开关对照：相同Seed、1280×720、60fps、同输入、同静止训练目标、air focus关闭；banner关闭／开启各约12秒。两段实际玩法轨迹完全一致，源稳定；不是历史commit前后，也不签动作／玩法改善或实体设备帧率。
- 真实引擎MovieWriter→H.264/AAC，48kHz双声道；未用静图重建动画。保留原AVI在build，交付MP4及原输入轨迹。

[公开字节核验](public-bytes.json)确认完整PCK `141820280`字节、SHA `adee7889f8a988be5d224d2f5df00b68f71daed00da64a9e59a532abbbb0a388`，实际MP4 SHA `3e6efc33b970de2c0e05f1a4adb424f3c79cab06c722e7040d282d03e91ff903`，正式站build-info前后完全一致（`703f9b040e5f` / source `9c349f44...`）。[最终公开GUI](public-gui.json)实跑WASM、键盘／指针及实际STUDIO_EVENT jump/shot、OCR定位按钮并点击返回菜单，errors为空；[入口](entry.png)与[完整菜单](full-menu.png)是实际截图。

[原fresh Harness](harness/report.json)绑定精确6ca72ef、干净工作区：14规划器、30交付测试、25真实原生断言及音频释放。[独立审查](review.json)只签技术范围；[原158检查及profile前缀保留](guard-preservation.json)。完整docs因本地稀疏检出未物化旧证据而失败；[原失败](failures/docs-sparse-original.log)保留，未被局部检查代签。完整集成／Release、玩家、手机／手柄真机均未签。

首次公开候选因官方Web模板禁止位置场景参数而失败，见[原件](failures/web-path-overrides.json)。改用显式`--cloud-preview`经真实默认入口重定向；bootstrap宿主标记阻止递归。该失败候选已退出活跃站点，完整原运输树仍在host commit `f3bf28b`及本地恢复包；未删源仓库历史。Release附件上传401原件见[日志](failures/release-upload-401.log)，实际采用`stage-media`静态下载，不拼造Release链接。

复现：按[生产入口](../../cloud_production.md)安装固定工具链，执行原Harness三项新check、`build.py web`、`capture_slice.py`及`cloud_delivery.py stage-preview/stage-media`；网页驱动原文为[browser_driver.py](browser_driver.py)。工具与源码/导出身份分开，未执行项目不标通过。

具体反馈点：开发标识与FULL GAME / MENU按钮是否足够清楚、是否干扰观察动作。用户尚未评价，不能据此签审美／手感／趣味。
