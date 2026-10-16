# Documentation CI 的图像测试依赖

原 GitHub run `38815139583` 的真实日志显示 docs profile 前19项检查通过，最后 visual-director-tests 失败。原工作流在 setup-python 后直接执行 harness，没有安装 `tests/test_visual_director.py` 原本就必需的 PIL；同仓库 Godot core 工作流已安装 `tools/requirements_art.txt`。

在新建 Python 3.12.14 隔离 venv（`include-system-site-packages=false`）中，直接执行未改动的原测试，真实退出1：`ModuleNotFoundError: No module named 'PIL'`。随后执行与已有 core job 完全一致的有界安装命令，安装既有固定版本 `Pillow==12.3.0` 成功；同一 venv 执行同一原入口真实退出0，17项全通过。源码字节与 HEAD 相同，未删除、跳过或改变任何断言。

唯一生产修改是在 `.github/workflows/docs.yml` 的 harness 之前加入已有 requirements 安装，`--retries 1 --timeout 20`，step `timeout-minutes: 2`。`workflow.diff` 是完整修改。没有更改游戏、资产、Router、TTL或其他源码，没有运行 Godot。

已对该新 run 的 harness-docs artifact 做一次安全访问，实际返回 Forbidden，未重试；签名 URL 未打印或存储。远程仅有 harness 汇总失败，详细测试 traceback 未取得，因此本地已证缺依赖不能冒充远程原异常已确证为唯一根因。新的远程工作流仍须父任务提交后验证。这里的17项是原工具单元/故障注入测试，不能作为实机美术品质证据。

原始日志、安装与复验退出码/时间、源文件、隔离配置和来源 SHA 见 `archive_index.json`、`summary.json`。
