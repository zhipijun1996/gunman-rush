# 可运行的失败候选，不是黄金发布

精确运行源 `3188a5a088d1fdb2989ae0a3d439b24c2a536cb0`；build `888ba552aa53`。源码与精选证据随分支保存；大影片/ZIP仅本地交付，完整绝对路径和SHA见 [download.json](download.json) / [movie.json](movie.json)，没有声称远端附件已上传。

Linux x86_64 ZIP 236,788,372字节；解压进入目录执行 `./play.sh`。A/D或方向键移动，空格跳，鼠标瞄准/左键射击；右上角可切换原信使、围巾旅人、修钟少女，都是外观。包为原手动入口，无自动驾驶或Meta写入。默认joint-recoil-01，其他Seed没有由本包冒领艺术准入。

完整原片58,806,382字节，正常1280×720/60fps，48k双声道；真实4530路线tick、8段实际输入路线，零回退，最低HP4最终5。不是旧4529tick PNG采样的重标，也不是静态图推拉镜头。音频流存在不等于已实际听音；没有真人或设备认可。

本包1497项输入逐字节核对；PCK确实嵌入ZIP，非临时symlink。空cwd headless/GUI实际启动及严格退出通过，实际2mesh/2实体多边形/3旧矩形退出/装饰碰撞为空/角色与源图闭包相符。见 [真实回执](build_receipt.json.gz)、[归档核验](archive_verification.json)、[实际打包GUI](actual_packed_gui.png)。这是启动/闭包验证，不是包内完整路线重放或艺术验收。

第一包遗漏继承区域catalog所需原PNG，真实启动失败，见 [失败回执](failed_first_build_receipt.json.gz)；只补充实际资源输入后重新构建，没有删原守门或忽略日志。原严格生产器保持原件，当前 [producer.py](producer.py) 只绑定联合候选及实际依赖/节点校验，无平行打包框架。

恢复：先检出精确运行源，恢复本目录适配器和原严格生产器，按recipe重新生成严格采集；然后：

```sh
python3 docs/evidence/plains_joint_recoil/delivery/producer.py --execute --expected-commit 3188a5a088d1fdb2989ae0a3d439b24c2a536cb0 --expected-capture build/plains_joint_recoil/movie_v4_failed_01/visual_capture.json --output-dir build/plains_joint_recoil/NEW_LOCAL_REVIEW
```

先不加`--execute`可读计划。真实采集中的时间/输入敏感性可能让新路线tick略有变化，应保留新源回执，不复制旧录像结果。美术REWORK；未运行完整CI/Web门槛、真人/设备/听音/性能预算，非正式发布。Godot MIT许可随包，新图模型/商用许可未知。森林/核心/正式池未改。

完整打包回执含约74,000行闭包数据，仅按需解压读取；gzip逐字节保留原件，SHA见[压缩索引](receipt_index.json)，默认入口只需本页、download/movie及独审。
