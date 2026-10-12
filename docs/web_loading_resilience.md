# D083 试玩加载和大陆部署边界

本轮基于 D082 最新 Git，保留两张平原地图、Boss/输入/精力/美术消费者/账本。仅 Web 导出剔除没有运行消费者的 painterly_v2 历史候选；源图、历史证据和其他平台打包不变。`check_web_bundle.py` 检查新消费者是否引用该排除目录，避免以后接入却未导出。

## 下载与缓存

PCK 与官方 WASM 切成512 KiB独立块，原字节SHA256命名，gzip独立压缩；原官方文件保留兼容路径。每资源3路并发，每块3次重试、500/1000 ms间隔，30秒无数据则取消；有持续数据的慢连接不会被总时限切断。官方Godot的4次资源重试未改。最大等待有界，失败提示允许继续，刷新复用完成分块，不自动转为完整未压缩下载。小块是文件级恢复，不声称HTTP Range恢复半个块。

每块与完整重构均检查长度和SHA256；完整缓存命中也检查，坏缓存删除并由块重建。资源指纹隔离、同URL多标签共用在途下载。旧Worker确认当前包和加载器实现指纹后才开始，4秒内无法接管则兼容启动；不支持解压/Worker仍使用官方原文件。引擎不随纯玩法更新重复下载。完成后移除加载提示，不影响局内输入。

持久完整资源FIFO预算128 MiB，分块80 MiB；容量拒绝降级为不保存缓存，游戏仍可运行。只操作 gunman-rush-runtime-v1 / gunman-rush-chunks-v1，不清IndexedDB/localStorage。预算是单个源/worker的自有缓存上限，不承诺浏览器一定提供208 MiB空间；低配手机的解压/校验CPU与内存仍待真机测量。

构建生成完整`chunks/`、原PCK/WASM、worker及`build-info.json`。`download_bytes`统计压缩PCK/WASM响应体，不含JS/HTML/请求头；不可用总部署文件大小冒充首次下载量。CI构建后逐块解压重构比对官方文件，再上传与发布。

## 大陆镜像

GitHub Pages在大陆可能慢或不可达；减小包和恢复只能改善能够连上时的成本，不能解决域名连不上的问题。目前环境没有国内托管身份，国内镜像**尚未上线**，不虚构镜像链接或大陆测速。

可将同一个Web产物整体放到用户控制的国内HTTPS站点/对象存储/CDN，不依赖外部字体、音效、GitHub代理。提供 [Nginx配置示例](../tools/web/nginx-playtest.conf)：替换域名/证书/root，完整上传目录，包括`chunks/`，HTML/manifest/worker需重新验证缓存，指纹资源一年immutable。Godot当前单线程导出不要求COOP/COEP，需WebGL2、HTTPS和正确WASM MIME。分块gz可以普通二进制提供；若CDN加Content-Encoding:gzip，loader避免双重解压。域名备案/服务开通由既有托管条件决定，本次不购买服务。

部署宜先上传新指纹资源和全部块，最后切换HTML/worker/manifest；保留最近版本文件一段时间可支持旧标签重载。不得把缺失资源重定向HTML或替换为新版本文件。浏览器永久存档按源隔离，镜像首访不会自动拥有GitHub源的存档；本次未新增跨源导入或云存档。

## 验证

`python3 tools/build.py web`、`python3 tools/check_web_bundle.py`；真实Chromium故障测试 `python3 tools/verify_web_resilience.py --before build/verification/web-loading-d083/before --after build/web`。保存探针是存储保留检查，不冒充实际赚到音符。测试结果、严格审查与公开包以[当前交接](handoff.md)为准。

本地最终加载器234d72d01676实测：首次响应体43,136,956→34,952,921 B（约19%减少）；暖载368 B，仅manifest。含实际分块故障/缓存损坏/双标签/更新证据见[报告](evidence/web_loading_d083/local_loading.json)。本地无限速可能增加分块/存储初始化成本，不能保证快网墙钟时间也更快；限速结果另记。

人工限速实测：总吞吐1 MiB/s、每请求120 ms延迟，冷启动46.555→39.107秒，减少约16%；[报告](evidence/web_loading_d083/bandwidth.json)。这是可复现弱链路模拟，不能称为大陆网络/手机或Pages实际吞吐。无限速localhost6.033→8.821秒，快网初始化开销确实增加。禁用Worker冷载约63.55 MB，保留兼容但不能享受分块传输优化。旧工具--recovery-checks对schema2委派新suite，schema1旧gzip断言保留。
