# D083 Web 加载与大陆直连交接

分支 `fix/web-loading-resilience` 基于远端最新 D082 `53f88e5`；工作区起初干净，main 与此前功能分支保持原关系，不合并 PR。完整 D082 玩法、证据及已知导出诊断见[归档](archive/handoff_d082.md)。

本轮仅改 Web 打包/传输/缓存/部署文档，无玩家物理、输入、奖励、存档或地图变化。Web 排除无运行消费者的 painterly_v2 旧候选美术，原图与其他平台导出保留。当前本地 PCK 32,750,248→25,293,944 B；分块压缩总传输34,561,192 B，不包括HTML/JS/请求头。最终公开包以发布实测为准。

实现：PCK/WASM 512 KiB 独立 SHA256/gzip 分块，同资源3路下载，每块3次有界重试、30秒无数据超时；官方loader原有4次资源重试保留。刷新仅请求缺失块；坏分块与坏完整缓存都拒绝并重建。完整缓存128 MiB、分块80 MiB FIFO预算，不清Godot保存。双标签同URL合并下载，旧Worker同时核对当前包指纹与加载器实现指纹；4秒以内未接管走官方兼容路径。加载页显示准备进度及继续按钮，进入游戏移除。

大陆边界：仍托管在GitHub Pages，没有可用国内托管账号/域名；不能保证该域名无VPN可达。完整同源静态包与HTTPS Nginx配置可部署到国内主机/CDN；不使用公共GitHub代理，不让运行依赖转回国外。不同域名的浏览器存档隔离，不声称自动同步。[加载与镜像说明](web_loading_resilience.md)。

本地完整Core5942/0、文档/世界设计、预算并发单测、官方资源逐块重构、最新故障浏览器均通过；[实际冷暖与恢复报告](evidence/web_loading_d083/local_loading.json)。首次响应体43,136,956→34,952,921 B，减少约19%；暖载仅368 B manifest，无PCK/WASM/块请求。同PCK换Worker、旧包换新、两个冷标签122块零重复、首/末块断网、坏gzip内容、坏完整/分块缓存、保存探针保留、禁用Worker兼容均通过。限速、普通正式入口与公开发布仍进行中，需补齐。旧verify_web_loading损坏wasm.gz测试属于旧路径，不能冒充新分块证据。本轮首次fault注入3次不足以耗尽官方4次重试，页面实际上成功，等待失败提示超时；保留记录，故障改为12次，不修改成功/哈希判定。

首三轮独立审查：[否决1](evidence/web_loading_d083/review_round1.md)、[否决2](evidence/web_loading_d083/review_round2.md)、[条件通过3](evidence/web_loading_d083/review_round3.md)。后续坏CacheStorage归因断言曾失败：正确块从浏览器HTTP缓存恢复，未发生服务器GET；故障服务器为块加no-store，隔离HTTP缓存并保留严格“只请求坏块”断言。

首块故障测试最初错误地要求仅补故障块，实际其他线程按停止规则还留下未请求块；现读取刷新前已完成CacheStorage清单，严格禁止重下其中任何块、禁止重复缺失块，同时末块故障仍必须恰好补1块。保留失败输出。有效缓存块不重复写入，减少修复路径存储开销。

限速真实浏览器对比（总吞吐1 MiB/s、每请求120 ms人工延迟）：冷启动46.555→39.107秒，减少7.448秒（约16%）；该值不是大陆测速。无限速localhost冷启动6.033→8.821秒，保留性能代价。[限速报告](evidence/web_loading_d083/bandwidth.json)。旧verify_web_loading的--recovery-checks遇schema2现委派完整新故障suite，schema1保留原损坏wasm.gz断言。

等长坏gzip/等长坏整包缓存/等长坏分块缓存实际强制SHA负例通过，[报告](evidence/web_loading_d083/equal_length_integrity.json)。[第4轮审查](evidence/web_loading_d083/review_round4.md)指出的旧验证CLI委派已修，待最后复核。

[第5轮独立复核](evidence/web_loading_d083/review_round5.md)通过：旧CLI无递归、失败码透传、等长攻击强制SHA。正式本地GUI首请求指向旧已关闭8060端口，连接拒绝；重启静态服务器后保留原验证判定重跑，结果通过。

正式本地GUI[报告](evidence/web_loading_d083/local_region_gui.json)failed=0：真实家园步行/交互/购买、刷新保存、出发进入随机探索图，迷雾大图缩放拖动关闭、实际跳跃/射击输入正常。9音符为独立保存fixture，不称实际赚币；完整真人通关/手机/大陆连接仍未验。下一步推送本轮运行提交、PR及完整CI发布，然后核对公开PCK/加载器/正式入口。
