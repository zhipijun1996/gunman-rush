# Web 首次下载与重复加载

运行权威仍为锁定的 Godot Standard；优化的是导出后的传输与缓存，不修改引擎二进制、玩法、输入或存档。

## 现有问题与实现

旧导出只有 PCK 内容哈希，JS/WASM 固定文件名；Godot fetch 在实测重复加载时仍重新下载 37.9 MB WASM 与 8.48 MB PCK。旧 freshness 脚本还会自动跳转整页，打断正在玩的局。

`python3 tools/build.py web` 现在生成：

- `index.<engine-hash>.engine.js/.wasm` 与同前缀音频 worklet；引擎哈希包含实际 JS、WASM 和两个 worklet。PCK 仍用独立内容哈希，纯玩法更新不需要重新下载引擎。
- 同时保留官方原 WASM，并生成可重复的 `.wasm.gz`（gzip level 9、mtime 0）。这不需要 GitHub Pages 配置 Brotli 或 Content-Encoding。
- `index.cache-sw.js` 仅缓存带内容哈希的游戏资源，不接管 HTML、build-info、局内输入或任何保存接口。首次启动前最多等待 4 秒缓存接管；拒绝权限、非安全来源、旧浏览器会继续用官方资源启动。
- 支持 Service Worker + DecompressionStream 的浏览器下载 gzip、解压后核对原始长度与完整 SHA256，返回标准 `application/wasm` 响应。缺失、损坏、校验失败则回退原 WASM；缓存空间不足不阻止游戏运行。
- 已缓存的 WASM/PCK 再次打开直接使用。更新 worker 不清旧不可变文件，不把新版 PCK 替换进旧版运行会话。旧 HTML发现新版时只显示手动更新按钮，确认后更新；不会自动整页重载。

不删除正在使用的新 Home 四张 PNG、平原背景或碰撞资源；本次没有修改图片母版。所有 Godot 资源继续 `all_resources` 导出，避免新全局脚本/定义在并行开发时遗漏。音符/永久升级存储键及服务不变。

## 实际测量

`tools/verify_web_loading.py` 启动两个隔离 localhost 静态站点和独立 Chromium profile；各执行初载、真实 page.reload，并等待 Godot 启动遮罩移除。服务端统计真正发出的响应体字节，记录浏览器 Resource Timing。服务器保留普通 Last-Modified/304 行为，没有人为关闭旧 HTTP 缓存。

```sh
timeout 190 python3 tools/verify_web_loading.py \
  --before build/verification/web-loading/before \
  --after build/verification/web-loading/after --recovery-checks
```

最新集成包 `39edfde252ed`（15,505,264 B PCK，包含新 Home /菜单、出口、灰度远景、VFX，以及最终 Home 输入/镜头前瞻与远景 vertex tint shader 修复（运行提交 `f1105db`））已复制隔离快照实测。旧加载器 baseline 使用**相同新 PCK**和 SHA256 一致的官方原 WASM；仅恢复旧加载 HTML/未缓存资源命名，避免因新旧游戏内容不同夸大改善。根工作目录 `build/web` 未被修改。

| 相同最新 PCK 的浏览器实际响应体 | 旧加载器 | 新加载器 |
| --- | ---: | ---: |
| 冷启动 | 53,760,824 B | 25,891,193 B |
| 真实 reload | 53,407,605 B | 203 B，仅 build-info |

最新素材包冷启动流量减少约 **51.8%**；原 WASM 37,902,138 B，gzip 10,027,646 B。暖启动没有 PCK/WASM 网络请求。同包版本一致、页面无 JS 异常、localStorage 探针保存保留均实际通过；探针是存储隔离检查，不冒称真实捡音符验收。

localhost 冷启动 ready 旧 6.62 秒、新 6.91 秒；暖启动旧 4.03 秒、新 4.43 秒。时间包含额外等待 1.2 秒；本地几乎无网络延迟，gzip 解压与校验有 CPU 成本，因此不宣称这些数值是手机网速或稳定墙钟加速。收益是降低网络传输，Godot 初始化、纹理解码与加载场景仍需时间。

```sh
timeout 190 python3 tools/verify_web_loading.py \
  --before build/verification/web-loading-shader-final/before \
  --after build/verification/web-loading-shader-final/after --recovery-checks \
  --report build/verification/web-loading-shader-final/report.json
```

该最终包同时实测 Service Worker 拒绝与损坏 gzip 两种故障，均成功回退官方原 WASM；损坏 gzip 回退成功后的暖载仍只请求 203 B manifest。localStorage 探针均保留。iPhone Safari 尚未验证。

最新集成的完整 JSON/实际请求列表：本地 `build/verification/web-loading-shader-final/report.json`。构建报告和 build-info 记录实际引擎/PCK哈希、WASM/gzip字节数；该目录不提交。测量结束后若修改运行逻辑重新导出，新增包 ID 应单独记录，不冒称此快照是另一个包。

### 输入/镜头修复快照（保留，不覆盖）

输入/镜头修复快照 `99e75c94c91b`（15,505,056 B PCK，包含新 Home /菜单、出口、灰度远景、VFX，以及最终 Home 输入/镜头前瞻修复）已复制隔离快照实测。旧加载器 baseline 使用**相同新 PCK**和 SHA256 一致的官方原 WASM；仅恢复旧加载 HTML/未缓存资源命名，避免因新旧游戏内容不同夸大改善。根工作目录 `build/web` 未被修改。

| 相同快照 PCK 的浏览器实际响应体 | 旧加载器 | 新加载器 |
| --- | ---: | ---: |
| 冷启动 | 53,760,616 B | 25,890,985 B |
| 真实 reload | 53,407,397 B | 203 B，仅 build-info |

该快照素材包冷启动流量减少约 **51.8%**；原 WASM 37,902,138 B，gzip 10,027,646 B。暖启动没有 PCK/WASM 网络请求。同包版本一致、页面无 JS 异常、localStorage 探针保存保留均实际通过；探针是存储隔离检查，不冒称真实捡音符验收。

localhost 冷启动 ready 旧 9.09 秒、新 4.43 秒；暖启动旧 3.60 秒、新 3.12 秒。时间包含额外等待 1.2 秒；本地几乎无网络延迟，gzip 解压与校验有 CPU 成本，因此不宣称这些数值是手机网速或稳定墙钟加速。收益是降低网络传输，Godot 初始化、纹理解码与加载场景仍需时间。

```sh
timeout 190 python3 tools/verify_web_loading.py \
  --before build/verification/web-loading-final/before \
  --after build/verification/web-loading-final/after \
  --report build/verification/web-loading-final/report.json
```

输入/镜头修复快照的完整 JSON/实际请求列表：本地 `build/verification/web-loading-final/report.json`。构建报告和 build-info 记录实际引擎/PCK哈希、WASM/gzip字节数；该目录不提交。测量结束后若修改运行逻辑重新导出，新增包 ID 应单独记录，不冒称此快照是另一个包。

### 上一轮集成快照（保留，不覆盖）

上一轮集成快照 `286a7b8368cc`（15,504,256 B PCK，包含新 Home /菜单、出口、灰度远景和 VFX）已复制隔离快照实测。旧加载器 baseline 使用**相同新 PCK**和 SHA256 一致的官方原 WASM；仅恢复旧加载 HTML/未缓存资源命名，避免因新旧游戏内容不同夸大改善。根工作目录 `build/web` 未被修改。

| 相同快照 PCK 的浏览器实际响应体 | 旧加载器 | 新加载器 |
| --- | ---: | ---: |
| 冷启动 | 53,759,816 B | 25,890,185 B |
| 真实 reload | 53,406,597 B | 203 B，仅 build-info |

该快照素材包冷启动流量减少约 **51.8%**；原 WASM 37,902,138 B，gzip 10,027,646 B。暖启动没有 PCK/WASM 网络请求。同包版本一致、页面无 JS 异常、localStorage 探针保存保留均实际通过；探针是存储隔离检查，不冒称真实捡音符验收。

localhost 冷启动 ready 旧 5.10 秒、新 4.36 秒；暖启动旧 3.36 秒、新 3.55 秒。时间包含额外等待 1.2 秒；本地几乎无网络延迟，gzip 解压与校验有 CPU 成本，因此不宣称这些数值是手机网速或稳定墙钟加速。收益是降低网络传输，Godot 初始化、纹理解码与加载场景仍需时间。

```sh
timeout 190 python3 tools/verify_web_loading.py \
  --before build/verification/web-loading-integrated/before \
  --after build/verification/web-loading-integrated/after \
  --report build/verification/web-loading-integrated/report.json
```

上一轮集成的完整 JSON/实际请求列表：本地 `build/verification/web-loading-integrated/report.json`。构建报告和 build-info 记录实际引擎/PCK哈希、WASM/gzip字节数；该目录不提交。测量结束后若修改运行逻辑重新导出，新增包 ID 应单独记录，不冒称此快照是另一个包。

### 先前隔离验证与错误恢复

使用同一旧可玩 PCK `212641aed7ad` 做初轮隔离传输对照，最新新 PCK 已在上表独立测量。

| 同一 PCK 的浏览器实际响应体 | 旧加载器 | 新加载器 |
| --- | ---: | ---: |
| 冷启动 | 46,733,374 B | 18,863,845 B |
| 真实 reload | 46,380,156 B | 203 B，仅 build-info |

冷启动流量减少约 59.6%；原 WASM 37,902,138 B，gzip 10,027,646 B。暖启动没有 PCK/WASM 网络请求。同包版本一致、页面无 JS 异常、localStorage 探针保存保留均实际通过；探针是存储隔离检查，不冒称真实捡音符验收。

localhost 冷启动 ready 旧 4.44 秒、新 4.16 秒；暖启动旧 2.93 秒、新 2.84 秒。时间包含额外等待 1.2 秒；本地几乎无网络延迟，gzip 解压与校验有 CPU 成本，因此不宣称这些数值是手机网速或墙钟加速。收益是降低网络传输，Godot 初始化、纹理解码与加载场景仍需时间。

同一浏览器实际注入拒绝 Service Worker 与损坏 gzip 两种故障也均启动成功：前者回退官方原 WASM，后者校验/解压失败后回退，第二次使用完整缓存；恢复测试不是靠跳过失败返回成功。

完整 JSON/请求列表保存于本地 `build/verification/web-loading/current-report.json`（完整当前生成脚本）与 `report.json`（两种实际故障恢复）；构建报告和 build-info 记录实际引擎/PCK哈希、WASM/gzip字节数。该目录不提交。

## 边界与后续验证

缓存仅运行资源，不提供完整离线网页导航或中断后的任意旧包回滚。私密模式/配额拒绝可以照常运行，但可能重复下载。旧 Safari 如果缺少解压流，会下载官方原 WASM；Android/iPhone Safari 的首次/再次打开速度与缓存驱逐需分别实测。不能通过清全站数据优化加载：该动作还会删除永久进度。

最新集成包本地加载已实测，公开 Pages HTTPS、iPhone Safari 与实际存档验收独立记录。首次 PCK 已因用户要求的新 Home 素材增大；不能把同旧 PCK的绝对字节数套用于新素材。

## 已发布 HTTPS 的独立证据

运行提交 `6c50876` 的 CI 已通过并部署。实际公共 PCK 为 `5f12c2d13996`，15,507,824 B；本地 shader-fix PCK 为 `39edfde252ed`，15,505,264 B。二者哈希不同，不能写成同一二进制。公开包与 CI 下载产物的字节哈希一致；上面的同 PCK 旧/新加载器对照表仍仅代表本地 `39edfde252ed`。

已对两份 PCK 做只读目录解析，逐文件核实 PCK 内 MD5 与实际数据，随后以 Godot 4.7.2 ResourceLoader 只读读取变化资源，未运行 editor/import 或重导出：

- 两份包均 625 条，路径集合相同；574 条逐字节相同，包括全部导入纹理、shader、GDScript 与 config。
- 40 个导出 `.scn` 的变化来自 `_bundled.node_ids` 实例标识；9 个旧模块 `.res` 在 CI 显式序列化更多默认属性，本地省略。读取全部 49 份资源、递归比较存储属性、仅归一化场景/资源实例标识后，有效属性差异 **0**。
- 余下两个差异为 `.godot/global_script_class_cache.cfg` 与 `.godot/uid_cache.bin`。117 条全局类记录排序后完全相同，221 对 UID→路径映射完全相同，差异仅迭代顺序。

因此 +2,560 B 来自 Godot 导出默认值/标识/缓存序列化，不是旧脚本、错误素材或缺失资源。原始目录与有效属性证据位于本地 `build/verification/plains-polish/pck-directory-comparison.json`、`pck-semantic-{local,public,comparison}.json` 和 `pck-metadata-comparison.json`。

对 [公开 HTTPS 网页](https://zhipijun1996.github.io/gunman-rush/?v=5f12c2d13996) 用全新 Chromium profile 做了一次有界冷启动及真实 reload。实际包号两次均为 `5f12c2d13996`，Service Worker 均接管；JavaScript 无异常，localStorage 隔离探针保存保留。

| 公开浏览器 Resource Timing 覆盖传输 | 冷启动 | reload |
| --- | ---: | ---: |
| 页面与 worker 的 `transferSize` 合计 | 25,266,809 B | 803 B |
| PCK/WASM 再次网络传输 | 首次下载 | 0 B |

暖载 803 B 为 HTML 重新验证（API 计 300 B）和小型 build-info（203 B 响应体、API 含 header 计 503 B）。这些是页面与 worker Resource Timing 覆盖的传输，不是完整线缆抓包；浏览器未暴露的 Service Worker 注册/检查请求不计入该表。公开服务器对 JS/PCK 还提供了自己的压缩，因此不能直接拿此表与 localhost 响应体字节计算百分比。首次 ready 5.32 秒、reload 3.31 秒，仅代表该 Chromium/网络当次观测。

完整公开报告：本地 `build/verification/plains-polish/public-loading.json`。这不是实际捡音符的测试；玩法 GUI 与真实拾取/保存证据由独立浏览器验收记录。**iPhone Safari 与 Android 真机加载/缓存驱逐仍待验证**，不把公开 Chromium 通过推断为移动设备通过。
