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

最新集成包 `99e75c94c91b`（15,505,056 B PCK，包含新 Home /菜单、出口、灰度远景、VFX，以及最终 Home 输入/镜头前瞻修复）已复制隔离快照实测。旧加载器 baseline 使用**相同新 PCK**和 SHA256 一致的官方原 WASM；仅恢复旧加载 HTML/未缓存资源命名，避免因新旧游戏内容不同夸大改善。根工作目录 `build/web` 未被修改。

| 相同最新 PCK 的浏览器实际响应体 | 旧加载器 | 新加载器 |
| --- | ---: | ---: |
| 冷启动 | 53,760,616 B | 25,890,985 B |
| 真实 reload | 53,407,397 B | 203 B，仅 build-info |

最新素材包冷启动流量减少约 **51.8%**；原 WASM 37,902,138 B，gzip 10,027,646 B。暖启动没有 PCK/WASM 网络请求。同包版本一致、页面无 JS 异常、localStorage 探针保存保留均实际通过；探针是存储隔离检查，不冒称真实捡音符验收。

localhost 冷启动 ready 旧 9.09 秒、新 4.43 秒；暖启动旧 3.60 秒、新 3.12 秒。时间包含额外等待 1.2 秒；本地几乎无网络延迟，gzip 解压与校验有 CPU 成本，因此不宣称这些数值是手机网速或稳定墙钟加速。收益是降低网络传输，Godot 初始化、纹理解码与加载场景仍需时间。

```sh
timeout 190 python3 tools/verify_web_loading.py \
  --before build/verification/web-loading-final/before \
  --after build/verification/web-loading-final/after \
  --report build/verification/web-loading-final/report.json
```

最新集成的完整 JSON/实际请求列表：本地 `build/verification/web-loading-final/report.json`。构建报告和 build-info 记录实际引擎/PCK哈希、WASM/gzip字节数；该目录不提交。测量结束后若修改运行逻辑重新导出，新增包 ID 应单独记录，不冒称此快照是另一个包。

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
