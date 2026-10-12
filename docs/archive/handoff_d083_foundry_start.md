# D083 Web 加载与大陆直连交接

正式运行提交 **26906a435c18c79762f0ea8f655a4e1cf8b4f915**，分支 `fix/web-loading-resilience`，基于D082最新53f88e5；本次后续提交只补证据/文档。远端main仍ab51fca，D082/之前功能PR未自动合并；PR52文档分支已关闭未合并，没有覆盖其分支内容或用户工作区改动。起始工作区干净。

公开试玩 **[74867f67fb81](https://zhipijun1996.github.io/gunman-rush/?v=74867f67fb81)** 已更新。[PR53](https://github.com/zhipijun1996/gunman-rush/pull/53)保持开放，[发布CI38232680571](https://github.com/zhipijun1996/gunman-rush/actions/runs/38232680571)成功，不合并PR。实际下载线上138个构建文件逐一核对大小/SHA256：PCK **25,300,664 B**，SHA **74867f67fb81cd2b139f3cdfda14aa9e1c10f5fa5257b01ad82ce87646ab9049**，线上loader_id **aa5082608f05**，source_commit与运行提交一致。原始官方PCK/WASM逐块重构相同；[公开包证据](../evidence/web_loading_d083/public_package.json)。

[线上普通GUI](../evidence/web_loading_d083/public_region_gui.json)failed=0、正确新版本：标题→家园真实行走/购买/刷新保存→正式随机平原，迷雾地图缩放拖动关闭、真实跳跃和瞄准释放正常。9音符为独立profile的fixture，不称实际赚到；完整真人通关/手机及大陆连接待验。CI Core **5942/0**、原 **43套**、地区 **15套**、100素材检查、Windows/Web导出、分块重构/并发预算均通过。[CI摘要](../evidence/web_loading_d083/ci_completion.txt)。保留继承的4条windkeeper.tscn:13 Busy导出和退出诊断，[原文](../evidence/web_loading_d083/export_diagnostics.txt)，不能称日志零诊断。

首次响应体本地43.14→34.95MB，减少约19%；人工总吞吐1MiB/s、每请求120ms冷启46.555→39.107秒，约16%改善；暖载368B manifest，不重下PCK/WASM/分块。localhost快网6.033→8.821秒，初始化成本增加，不宣称所有环境更快。线上分块PCK/WASM压缩响应体34,563,473 B，不含HTML/JS/请求头。版本差来自干净CI导入，不把本地包当公开包。

国内镜像**尚未部署**，没有国内服务器/CDN身份或域名；GitHub Pages大陆无VPN可达性仍未实测/解决。已从实际公开文件生成完整部署ZIP `build/gunman-rush-web-74867f67fb81.zip`（79,277,148 B），含许可证、全部分块、兼容原文件及HTTPS Nginx配置。可交给已有国内主机/CDN部署，原源保存不自动跨域同步。[说明](../web_loading_resilience.md)及[完整机器证据](../evidence/web_loading_d083/verification.json)。不使用公共代理，不购买服务。GitHub构建附件下载返回Forbidden，改从公开站点校验138文件成功，未绕过其访问控制。

五轮独立审查保留两轮生产否决、缓存归因与未下载块测试失败、旧CLI迁移要求；全部修复复核，最终旧CLI完整suite与等长SHA负例通过。清理仅自有资源缓存，基础物理/输入/精力/奖励/保存与D082相同。[D082归档](handoff_d082.md)。

后续：接入用户已有国内HTTPS主机/CDN后再测大陆运营商直连、手机CPU/内存与冷暖速度；不重复改玩法。现有回归/源哈希不能代替这些真机网络结果。

## 本地实施与保留的迭代记录


分支 `fix/web-loading-resilience` 基于远端最新 D082 `53f88e5`；工作区起初干净，main 与此前功能分支保持原关系，不合并 PR。完整 D082 玩法、证据及已知导出诊断见[归档](handoff_d082.md)。

本轮仅改 Web 打包/传输/缓存/部署文档，无玩家物理、输入、奖励、存档或地图变化。Web 排除无运行消费者的 painterly_v2 旧候选美术，原图与其他平台导出保留。当前本地 PCK 32,750,248→25,293,944 B；分块压缩总传输34,561,192 B，不包括HTML/JS/请求头。最终公开包以发布实测为准。

实现：PCK/WASM 512 KiB 独立 SHA256/gzip 分块，同资源3路下载，每块3次有界重试、30秒无数据超时；官方loader原有4次资源重试保留。刷新仅请求缺失块；坏分块与坏完整缓存都拒绝并重建。完整缓存128 MiB、分块80 MiB FIFO预算，不清Godot保存。双标签同URL合并下载，旧Worker同时核对当前包指纹与加载器实现指纹；4秒以内未接管走官方兼容路径。加载页显示准备进度及继续按钮，进入游戏移除。

大陆边界：仍托管在GitHub Pages，没有可用国内托管账号/域名；不能保证该域名无VPN可达。完整同源静态包与HTTPS Nginx配置可部署到国内主机/CDN；不使用公共GitHub代理，不让运行依赖转回国外。不同域名的浏览器存档隔离，不声称自动同步。[加载与镜像说明](../web_loading_resilience.md)。

本地完整Core5942/0、文档/世界设计、预算并发单测、官方资源逐块重构、最新故障浏览器均通过；[实际冷暖与恢复报告](../evidence/web_loading_d083/local_loading.json)。首次响应体43,136,956→34,952,921 B，减少约19%；暖载仅368 B manifest，无PCK/WASM/块请求。同PCK换Worker、旧包换新、两个冷标签122块零重复、首/末块断网、坏gzip内容、坏完整/分块缓存、保存探针保留、禁用Worker兼容均通过。限速与正式入口通过，最终公开结果见上方。旧verify_web_loading损坏wasm.gz测试属于旧路径，不能冒充新分块证据。本轮首次fault注入3次不足以耗尽官方4次重试，页面实际上成功，等待失败提示超时；保留记录，故障改为12次，不修改成功/哈希判定。

首三轮独立审查：[否决1](../evidence/web_loading_d083/review_round1.md)、[否决2](../evidence/web_loading_d083/review_round2.md)、[条件通过3](../evidence/web_loading_d083/review_round3.md)。后续坏CacheStorage归因断言曾失败：正确块从浏览器HTTP缓存恢复，未发生服务器GET；故障服务器为块加no-store，隔离HTTP缓存并保留严格“只请求坏块”断言。

首块故障测试最初错误地要求仅补故障块，实际其他线程按停止规则还留下未请求块；现读取刷新前已完成CacheStorage清单，严格禁止重下其中任何块、禁止重复缺失块，同时末块故障仍必须恰好补1块。保留失败输出。有效缓存块不重复写入，减少修复路径存储开销。

限速真实浏览器对比（总吞吐1 MiB/s、每请求120 ms人工延迟）：冷启动46.555→39.107秒，减少7.448秒（约16%）；该值不是大陆测速。无限速localhost冷启动6.033→8.821秒，保留性能代价。[限速报告](../evidence/web_loading_d083/bandwidth.json)。旧verify_web_loading的--recovery-checks遇schema2现委派完整新故障suite，schema1保留原损坏wasm.gz断言。

等长坏gzip/等长坏整包缓存/等长坏分块缓存实际强制SHA负例通过，[报告](../evidence/web_loading_d083/equal_length_integrity.json)。[第4轮审查](../evidence/web_loading_d083/review_round4.md)指出的旧验证CLI委派已修，待最后复核。

[第5轮独立复核](../evidence/web_loading_d083/review_round5.md)通过：旧CLI无递归、失败码透传、等长攻击强制SHA。正式本地GUI首请求指向旧已关闭8060端口，连接拒绝；重启静态服务器后保留原验证判定重跑，结果通过。

正式本地GUI[报告](../evidence/web_loading_d083/local_region_gui.json)failed=0：真实家园步行/交互/购买、刷新保存、出发进入随机探索图，迷雾大图缩放拖动关闭、实际跳跃/射击输入正常。9音符为独立保存fixture，不称实际赚币；完整真人通关/手机/大陆连接仍未验。推送、PR、完整CI发布及公开核对已完成。
