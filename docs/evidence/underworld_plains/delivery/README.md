# Underworld 正式平原最终 Web 交付

任务 `UNDERWORLD-PLAINS-01`。最终运行源 **F**：`a44b856e1730e81ed74aa5eb1c8999e8d2bb8ff2`，build **`4b01de439c24`**。没有合并 main。

[正常标题试玩](https://zhipijun1996.github.io/gunman-rush/?v=4b01de439c24) · [正式平原直达](https://zhipijun1996.github.io/gunman-rush/?plains=1&v=4b01de439c24) · [保留五风格实验](https://zhipijun1996.github.io/gunman-rush/?styles=1&v=4b01de439c24)

| 实际身份 | 值 |
| --- | --- |
| 运行源 ref | `delivery/underworld-plains-source-4b01de439c24` |
| 完整 PCK | `index.4b01de439c24.pck`，`132559084` bytes |
| 完整 PCK SHA256 | `4b01de439c241004d9148bf5958de524d14dda3ae5bc56b67c2731312856b46c` |
| Prepared ref / commit | `playtest/underworld-plains-4b01de439c24` / `428353bb8961180d2394c31335bb1f363702bbcb` |
| Pages run / attempt | [39248153645 / 1](https://github.com/zhipijun1996/gunman-rush/actions/runs/39248153645)，success |

[机器交付身份](final_delivery.json) · [实际PCK闭包](underworld_closure_F.json) · [公开完整字节与12份许可](public_bytes_F.json) · [本地GUI](browser_local_F.json) · [公开GUI](browser_public_F.json)

复用原 `build.py web`、缓存/chunks检查、许可sidecar与prepared Pages工作流。PCK只在Git传输中省略单文件，原512KiB内容寻址gzip chunks保留；真实Pages job重建并验证整个PCK后发布。公开端又下载完整PCK核SHA/长度、逐件核12份许可，没有删运行资源来规避Git单文件限制。

## 真实raw导出修复

E包的画面/导入纹理正确，但原始PNG没有作为raw条目导出，公开三层 `texture_sha256` 为空。该真实反例保留在 `previous_E/`、`final_delivery_E.json` 与 `raw_export_fix/E_actual_counterexample.json`，没有把E媒体重标F。

F只修改原EditorExportPlugin、三份preset明确路径、交付检查与测试。七张原PNG分别由既有全局资产manifest六个SHA及terrain_build原source_sha绑定，原family路径、排除冲突、通配拒绝规则保留。没有改变E的scripts/assets/scenes/resources/config/shaders/project.godot游戏或美术字节。

实际F PCK检查：**7份raw原字节、33份正常导入纹理衍生字节、12个资源/脚本、14份JSON均通过**；raw添加没有替代正常Texture2D导入。旧插件原28断言/旧Python2测试、新插件80断言/新Python5测试均通过，原日志保留。

本地与公开cooked Godot实际输出的三层SHA均非空且相同，严格等于原PNG：

| 景层 | 实际runtime SHA256 |
| --- | --- |
| far | `c99e5c0c7d86710345f291baf7ee4950995b59b3e0da8034be7fe5f145a78e3e` |
| middle | `b736998135fcc8f7a9a740634dbc33e585f3ebfdf79b4a55395405ae2365e4c2` |
| near | `32ea3038c8388b4df3898e0803d02ca7ad76634d5745019cbde3057d66c6ccf2` |

## 浏览器实际范围

真实Chromium canvas、鼠标/键盘、1280×720原图与连续WebM；0script/shader/resource错误。浏览器模拟不代表实体设备。

- F本地从普通标题进入map1；独审从F原WebM确认真实起跳（54.5s帧HUD0/1、脚明显高于岸顶）与移动。之后水平driver落坑，不能签跨缝落地。文件名 `03-map1-after-landing.png` 是历史标签，不代表实际已落地。
- F公开额外先原地Space：90ms早期帧明确离地且HUD0/1，后续同出生平台恢复1/1；三张原图为 `01a/01b/01c`。随后D400ms/Space260ms水平试验另行保留，不以画面差异或输入发送本身签Motor接受/完整路线。
- 两组均保留第二图既有 `pixel_inspect=2` 位置夹具与三个地标，以及原五风格实验入口。所有positioned媒体都不签自然跨图通关；这组公开场景未覆盖融合危险表面，native接触/四向/正式装配证据由主任务分别提供。

实际本地校验器是F提交内 `original_frozen_F_validator.py`，公开校验器 `browser_public_validator_F.py` 仅添加原地Space与原图采证，不改游戏状态或源码。各自SHA写入final_delivery。F以前的缺ffmpeg、OCR超时/漏读、URL编码、C的Foundry过期拒绝、D被独审停发等原失败全部在原E证据快照保留。

完整项目profile、所有正式路线、用户审美、声音与实体设备状态由主任务质量记录分别说明，发布成功不代表全面release。
