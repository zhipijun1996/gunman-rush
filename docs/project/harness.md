# CI与开发专项

## 日常验证

[tools/ci.py](../../tools/ci.py) 和 [production.yml](../../.github/workflows/production.yml) 定义四项日常检查，唯一Actions context为`affected`。

| 检查 | 范围 |
| --- | --- |
| project | 主场景、运行依赖、JSON配置和非运行目录导入隔离 |
| import | 锁定Godot编辑器导入，拒绝脚本／Shader错误、非零退出与超时 |
| smoke | 正式入口→家园→Explore平原→返回，验证真实玩家／控制器及退出 |
| contracts | 输入、跳跃、资源、伤害、交易及永久保存的必要契约 |

```sh
python3 tools/setup_environment.py --engine-only
python3 tools/ci.py
python3 tools/ci.py --check import --check smoke
```

PR、main push和手动CI使用同一套四项检查；自动CI不读取历史证据或手动测试表。发布与部署分别手动执行。

## 按任务选择专项

[模块导航](module_map.md) 给具体代码、设计和相关检查。注册命令、超时与成功标记维护在 [手动检查表](../../tools/harness/profiles.json)。

```sh
python3 tools/harness.py --list
python3 tools/harness.py --check core --plan
python3 tools/harness.py --check core
python3 tests/test_harness.py
```

不带参数仅列命令，`--plan`不执行；`--check`可重复，按顺序执行且首个失败停止。日志与简短结果保存到`build/verification/harness/`。没有profile自动升级、复用、隔离lane或全仓哈希步骤。

涉及世界设计、Bible、质量记录或生产工具本身时，可直接运行对应Python脚本；它们不属于日常CI门禁，也不自动要求额外质量卡。文档维护使用`tools/check_docs.py`；当前上下文导航回归为`tests/test_context_navigation.py`。

## 输入、证据与声明

稀疏环境按选定脚本的真实依赖取得所需资源；缺件明确报告。默认代码搜索限定模块导航给出的运行目录。当前设计直接修改正文，冻结测试输入只供对应版本的手动复现。

非零退出、超时、缺成功标记及脚本／Shader／资源退出错误均失败。测试、GUI、正常速度音画、独审、用户和设备分别记录实际覆盖；计划不代表通过。

## 发布与试玩

`tools/deliver.py`先运行四项CI，再按正式世界的受控资源清单导出；发行不生成旧Foundry实验批次。Windows／Android由`tools/export_native.py`执行`--export-release`，共用现有世界闭包，只包含正式43房及实际运行依赖，不包含工作台试验房、制作参考图、报告或生成器。版本唯一来源为project.godot的config/version。

[原生发行构建](../../.github/workflows/native-release.yml)手动固定提交构建Windows x86_64 ZIP及明确未签名的ARM64 APK，核43房真实装载、资源清单和Android非debuggable属性，并在Windows runner直接启动实际图形EXE，以既有隔离逐房入口装载P22，等待游戏HUD出现后检查正常／最大化／还原／大窗口的连续亮度和桌面截图，正常关闭后核退出及引擎日志。构建机显式使用Dummy音频，保留用户显卡和声卡复验边界；不以CLI强制截断退出或无界面启动替代真实窗口。公开APK必须经`tools/sign_android_release.py`签名与apksigner验证；新建密钥须显式指定`--create-key`，私钥与密码只保存在仓库外私有目录，不进入Git、工作流输入或Release。Windows ZIP保留EXE、PCK及许可，不能只分发EXE。构建报告绑定同一main源码、工具链与SHA256；发布后下载核对附件。

[environment.yml](../../.github/workflows/environment.yml)保留手动单平台交付与Web部署；只有显式勾选才部署Pages。

已有同源Web包使用 [prepared工作流](../../.github/workflows/deploy-prepared-playtest.yml) 发布，核公开build-info、完整PCK身份和真实入口。需要独立Preview时选独立托管目标。具体交付与跨会话恢复见 [协作规则](cloud_production.md)，测试取舍见 [CI说明](ci-test-inventory.md)。
