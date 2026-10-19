# 新47-tile美术地基证据

源提交 `222ee12fa002710de104d31f660ee275c1e6d2f6`；Web build `45c1a10f8767`。本目录精选真实原件，不含历史图片参考。

- [原始需求](user_request.txt)、[新规范](../../art_foundation_v1.md)、[独审](../../quality/blob47_independent_review.md)。
- [新鲜Harness报告](harness/report.json)：新地基、素材、结构、工具链4项通过；核心专项20356/0 + 958/0。
- [浏览器报告](browser/final/report.json)、[正常合屏](browser/final/01-playable.png)、[47目录](browser/final/02-catalog.png)、[移动镜头](browser/final/08-moving-camera.png)。`browser/final/video/`保存连续浏览器录像；software WebGL不签真机性能。
- `independent/`为不同作者实际拓扑、模块并集、装饰/RNG、one-way和10seed双向20路线探针及日志。
- `failures/`保留先前错误路线与空间缺陷；修复后另采，不抹掉失败。
- [完整profiles失败报告](full-profiles/report.json)：docs因本地稀疏检出未物化历史证据停止，后续全量检查未执行；没有删守门或签全绿。

范围仅新的地基和独立候选试玩；正式地图、完整敌人黄金、所有上路、纵向镜头、完整听音、用户审美及实体设备未验。

质量差异检查另因继承的 `assets/production_repair/` 目录常量适配器拒绝而失败，见 [日志](full-profiles/quality-diff.log)；新记录及素材记录独立结构校验无 errors，整体完成状态 UNVERIFIED。未修改旧适配器或守门以取得绿色。

已部署[HTTPS候选试玩](https://zhipijun1996.github.io/gunman-rush/?foundation=1&v=45c1a10f8767)，对应[草稿PR91](https://github.com/zhipijun1996/gunman-rush/pull/91)。source/build见上；正式地图不因预览上线而自动迁移或获审。

初期环境结构检查因稀疏检出未取回 tracked `.gdignore` 失败；恢复原文件后结构通过。中间一次边跑Harness边更新元数据被source-changed守门正确拒绝；最终冻结源四项fresh通过，失败报告保留在 `failures/`。

公网已[完整PCK哈希验证](public/hash-verification.log)及[真实GUI验证](public/report.json)，[公开画面](public/public.png)对应本轮新候选。原始完整profiles失败在源码检查点之前，report保留原e8ee344基线/diff，不伪装冻结源全profile通过。
