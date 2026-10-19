# Underworld 正式平原 Web 交付

任务 `UNDERWORLD-PLAINS-01`。本目录只记录本轮准确冻结源的交付，不能以既有实验 build `d2d469f81582` 代替本轮结果。

复用 `tools/build.py web`、`tools/check_web_bundle.py`、`tools/style_exploration_delivery.py` 与 `.github/workflows/deploy-prepared-playtest.yml`。大 PCK 经原内容寻址 gzip chunks 传输，Pages 重建后仍须核对整个公开 PCK 的长度和 SHA256。不新增站点，不合并 main。

冻结前只准备检查器与命令；实际状态以 `final_delivery.json`、原始命令退出码、Pages run/attempt 和公开端证据为准。缺少这些文件时，表示本轮尚未完成部署。

本轮补充检查器为 `tools/underworld_delivery.py`：

- `closure` 检查正式 Underworld 纹理的实际导出衍生字节、TileSet 资源、JSON 与脚本。`terrain/source.png` 是精确边界适配的运行采样资源，保留在包内；生成原图目录只作来源证据。
- `browser` 使用真实 Chromium canvas、普通标题鼠标入口、键盘走跳与连续录屏；第二图若通过项目已有 `pixel_inspect=2` 入口取景，明确记录为位置夹具，不能声称自然跨图通关。保留五风格实验入口。
- `public-bytes` 对公开完整 PCK 下载计算 SHA256/length，逐件核对许可 index 和全部 12 份公开许可文件。

建议顺序（`SOURCE`、`BUILD`、`PREPARED_REF` 只在实际生成后填写）：

```sh
python tools/build.py web
python tools/check_web_bundle.py
python tools/style_exploration_delivery.py check-bundle --commit SOURCE --output build/underworld_plains/delivery/style_closure.json
python tools/style_exploration_delivery.py licenses --commit SOURCE --output build/underworld_plains/delivery/licenses.json
python tools/underworld_delivery.py closure --source SOURCE --output build/underworld_plains/delivery/underworld_closure.json
python tools/underworld_delivery.py browser --source SOURCE --build-id BUILD --url http://127.0.0.1:8810/ --output build/underworld_plains/delivery/browser_local.json
```

本地实际检查通过后推送准确 source ref 和只含原导出 bundle/chunks 的 prepared ref；dispatch 现有工作流。部署成功后对正式 HTTPS 地址再执行 `public-bytes` 和 `browser`。`final_delivery.json` 绑定源提交、源 ref、prepared 提交/ref、run/attempt、build ID、整个 PCK SHA/length 与局部实际验证结果。

浏览器模拟不是实体设备验收；本轮有限输入不是完整路线/所有最差种子/声音终审。完整 profile 因继承历史闭包失败时保留原失败，不将部署成功追认为整个项目 release 通过。
