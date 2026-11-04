# 验证入口

检查ID、命令、输入、超时和成功标记唯一维护在 [profiles.json](../tools/harness/profiles.json)。本页说明选择与执行，具体主题的检查从 [模块导航](module_map.md) 定位。

## 开发与集成

```sh
python3 tools/production_plan.py --stage development --base <任务基线SHA>
python3 tools/production_plan.py --stage development --base <任务基线SHA> --execute
python3 tools/production_plan.py --stage integration --base <任务基线SHA> --execute
```

默认只保存计划；`--execute`执行选定检查并另存执行收据。Development选择相关短专项和必要消费者，Integration覆盖受影响系统；未知依赖及共享物理／随机／保存／公共配置按影响策略升级。`--precheck-only`只执行前置守门，`--verbose-plan`打印完整计划。

直接执行专项：

```sh
python3 tools/harness.py --check docs --check structure
python3 tools/harness.py --check level-region-context
python3 tools/harness.py --profile docs --plan
```

`--profile docs`包含文档、工具与生产合同的多项检查，并非一个轻量链接检查。完整profile范围以JSON定义为准。`core`增加引擎／核心回归，`gameplay`覆盖玩法消费者，`art`覆盖资产，`web`覆盖构建／加载，`full`去重合并适用检查。

## 执行与收据

Harness比较base...HEAD及暂存、未暂存和新文件。每次执行在`build/verification/harness/`保存报告和逐项日志，包含源码／工作区、工具链、实际argv、退出码和耗时。

非零退出、超时、缺成功标记及引擎错误都判失败；超时清理所属子进程。先定位失败的最小原runner，修复后复验，再运行所属聚合检查。源码冻结后执行集成，执行期间保持输入稳定。

开发`--reuse`只复用依赖摘要一致且原件可核的证明；Release要求的新鲜检查按原协议执行。计划、输入预检和测试结果分别记录；技术、GUI、独审、用户与设备分别验收。

## 稀疏检出与选定输入预检

新环境可partial clone并按任务物化，已有工作区先保护未提交内容。选定检查前规划实际输入：

```sh
python3 tools/cloud_inputs.py --check <ID>
python3 tools/cloud_inputs.py --profile <NAME>
python3 tools/cloud_inputs.py --check <ID> --materialize
```

默认只报告缺件与物化量；退出0为输入ready、2为待物化、1为阻塞，都不表示测试通过。`--materialize`只取得当前HEAD／index中skip-worktree缺件，不覆盖已有修改或普通删除；索引路径改变需先提交。报告写本工作树的新build路径。

检查前确认版本、SHA、原始来源与动态消费者。证据／源码副本按需加载，默认代码搜索限定game、scripts、scenes、resources、experiments等真实运行目录。

## CI前置检查与完整双通道

顺序为选定输入恢复 → 选中的便携前置检查 → 引擎／Foundry → 所选检查。仅完整集合与full精确相等时，使用现有两物理通道和合流协议：

```sh
python3 tools/harness.py --profile full --release --jobs 1 --lane parallel
python3 tools/harness.py --profile full --release --jobs 1 --lane serial
```

CI两通道使用同run、精确源码和准备产物，最终`affected`核工具链、输入、执行token、日志及完整覆盖。prepare或单通道成功不代表合流成功。重跑失败job复用同run合法准备产物，失败收据保持原身份。

## 正式交付

Release使用`tools/deliver.py`及现有精确源码CI／导出／GPU／音频／浏览器／公开包守门；`production_plan.py --stage release`只生成计划。发布前用`tools/check_release_evidence.py --commit <精确提交>`核证据属于该Git树。

试玩更新按 [协作交付](cloud_production.md) 选择已有同源Web包或必要重建。用户需要操作时交真实试玩入口，视觉观察可交真实短片；交付不扩大本次已验范围。
