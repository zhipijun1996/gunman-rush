# 工具链与环境

唯一版本、下载地址、补丁、二进制／模板 SHA 和平台依赖在 `config/toolchain.json`。当前使用 Godot 4.7.2 Standard 的固定回补构建 `gunman-sd1`；安装器核实际版本与内容，不以普通上游同版本号替代。

## 日常开发

```sh
python3 tools/setup_environment.py --engine-only
bash tools/godot.sh --version
python3 tools/ci.py
bash tools/godot.sh --path .
```

engine-only 只准备编辑器，不下载导出模板和平台 SDK。安装物、下载缓存和用户数据位于仓库外工具链目录，`GUNMAN_TOOLCHAIN_ROOT` 可指定位置；不把本机路径或凭据写进项目。

## 平台交付

按 `python3 tools/setup_environment.py --help` 选择所需范围。Windows／Web 导出使用锁定模板，Android 还需锁定 JDK／SDK 及显式的许可证处理。依赖缺失、校验不符或安装失败返回非零，不静默切版本。

`tools/check_environment.py` 输出实际环境检查到 ignored build；日常 CI、专项和发布各自声明所需依赖。部署和平台交付见 [Harness](harness.md) 与 [协作规则](cloud_production.md)。诊断只保留所需信息，密钥与代理凭据不进入记录。
