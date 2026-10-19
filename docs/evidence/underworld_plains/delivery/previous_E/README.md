# Underworld 正式平原 Web 交付

任务 `UNDERWORLD-PLAINS-01`。本目录记录最终运行源 E 的真实导出、公开完整包字节与浏览器验证，保留早期失败；没有合并 main。

[正常标题试玩](https://zhipijun1996.github.io/gunman-rush/?v=7915c17348c0) · [正式平原直达](https://zhipijun1996.github.io/gunman-rush/?plains=1&v=7915c17348c0) · [原五风格实验](https://zhipijun1996.github.io/gunman-rush/?styles=1&v=7915c17348c0)

| 身份 | 实际值 |
| --- | --- |
| 运行源 | `86535886c5b86e95bea094d7e92e57354be3d76e` |
| 源 ref | `delivery/underworld-plains-source-7915c17348c0` |
| Web build | `7915c17348c0` |
| 整个 PCK 长度 | `128733764` bytes |
| 整个 PCK SHA256 | `7915c17348c09c793b73e4c15ebcf22a67e899a333ead48247d6df8f19a3701b` |
| Prepared ref | `playtest/underworld-plains-7915c17348c0` |
| Prepared 提交 | `67baf5f8140222823eb7056e7c89bd53f69c9398` |
| Pages run / attempt | [39245171512 / 1](https://github.com/zhipijun1996/gunman-rush/actions/runs/39245171512)，success |

机器汇总为 [final_delivery.json](final_delivery.json)，逐文件 SHA/长度见 [evidence_index.json](evidence_index.json)。运行源标签不因后续证据或交付工具提交而改变。

## 包闭包与传输

使用既有 `tools/build.py web`、`check_web_bundle.py`、`style_exploration_delivery.py` 和 `deploy-prepared-playtest.yml`。正式 Underworld 闭包检查了 33 张纹理的实际导入衍生字节、12 个资源/脚本和14份JSON；原五风格闭包与通用缓存/chunks/运行资源检查也通过。`terrain/source.png` 与三张远景的实际导入纹理存在且已核对衍生字节；**原始PNG没有作为可FileAccess读取的raw条目导出**。公开诊断的三层 `texture_sha256` 因而为空，不能声称运行cached raw-source SHA已验证。详见 `raw_png_visibility_E.json`；本次视觉/导入纹理闭包通过不覆盖该原字节字段。

PCK 超过 GitHub 单文件100MiB限制，因此 prepared 分支只在 Git 传输中省略完整 PCK，保留原512KiB内容寻址gzip chunks。真实 Pages job 用原 helper 重建同字节整个 PCK 并校验 SHA/长度再发布；本地实际重建证据为 `prepared_reconstruction_E.json`。没有删除运行资产来规避包体限制。

`public_bytes_E.json` 证明公开端整个 PCK SHA/长度与冻结导出一致，以及 `style-licenses/index.json` 与全部12件许可字节逐项一致。实际下载的许可字节保留在 `public_license_bytes/`。128MB完整公开PCK与原候选包留在ignored build，不作为几十MB证据重复提交。

## 真实浏览器观察

两组均是实际 Chromium canvas、普通鼠标/键盘操作、1280×720原图和连续WebM。浏览器模拟不代表实体设备或帧率验收。

- `browser_local_E.json`：普通标题真实鼠标点击进入正式map1；发D/Space并保留原3帧；已有 `pixel_inspect=2` 定位第二图与三个地标；最后验证 `?styles=1` 和Underworld风格切换。独审另从原WebM抽帧确认实际起跳、跨缝、右平台落地与HUD从JUMP0/1恢复1/1。全屏画面差异本身不能证明Motor接受。
- `browser_public_E.json`：HTTPS上同样进入普通标题和正式map1。为拍清跳跃使用更早的D120ms/Space180ms输入，02原图清楚离地、HUD JUMP0/1；03实际落入缝隙，**不能称落地或完整路线通过**。原文件名 `03-map1-after-landing.png` 继承旧工具标签，实际观察以像素和录像为准。
- 公开第二图额外最多12次实际NEXT点击，console只确认10次新定位位置，均为junction/merchant，之后run结束。不能把12次尝试称12次接受，也没有在此范围拍到融合危险表面，公开hazard画面覆盖保持未验证。危险四向真实接触和正式伤害由主任务独立native专项证明。
- 本地与公开均无script、shader、resource或实际游戏资产HTTP错误；原五风格入口保留。所有 `pixel_inspect` 媒体明确为位置夹具，不签自然跨图通关。

## 保留的失败与交付工具修复

所有原日志、原媒体和原校验器保留，没有追改失败为通过。

1. 源 C `1cbf4966` 首次导出被Foundry过期basis拒绝，见 `export_1cbf4966_foundry_failure.*`。主任务用原规模36phrases/18itineraries重验晋升并stamp后再冻结新源。
2. 源 D `14e81362` 的导出/闭包通过，build为 `7a33d7328135`；独审指出repair地标覆盖不足后停发。D原包留在ignored `candidate_D_web`，本目录保留D闭包/导出记录，不能改签成E。
3. 首localGUI缺Playwright专用ffmpeg，原日志保留；安装实际官方工具后重跑。随后保留默认OpenMP造成的OCR超时，以及全屏/宽HUD OCR漏读的两轮原图、JSON、日志和视频。
4. 修复使用实际左上标题行像素 `(12,12)-(255,39)`、灰度反相4倍放大、PSM7与单线程OCR；原 `WINDCHIME PLAINS` / `1/2` 谓词保持，原全屏与精确crop均保存。
5. 首公开字节检查在含空格及 `&` 的Basic许可路径上curl URL编码错误退出3。完整PCK当时已正确下载并核SHA；失败JSON/log保留。只修 `urllib.parse.quote(name)` 后重新严格核完整包及全部12许可，通过。

`original_frozen_E_validator.py` 是运行源E提交内校验器的原字节。实际local/public/字节校验器副本和各自SHA见final_delivery汇总。`helper_post_E.patch` 记录后续可复用交付工具修复，属于非运行工具变化，没有重导或改签E的PCK；公开12NEXT和提前driver只在明确的build校验器副本执行。

本目录只证明有界预览交付。完整项目profile、正式地区全部路线、审美、声音、玩家与实体设备状态由主任务质量记录分别说明，不能从发布成功推出全面release通过。
