# Web CI Pillow依赖修复：独立限定审查

结论：接受本次两行workflow依赖修复，范围仅Python依赖准备。新增Web步骤在`harness --profile web --release`前安装`tools/requirements_art.txt`，与既有core及docs/environment.md标准命令一致；Pillow固定12.3.0，retries1/timeout20s，步骤2分钟有界；未改测试或降低门槛。

本审查另建真实Python3.12.14干净venv（不继承system_site_packages）：实际先跑原test_visual_director.py，出现ModuleNotFoundError:PIL；原样安装固定依赖成功；再跑原17测试3.320s全部通过。命令、返回码和安全日志见actual_fresh_venv_runs.json及without_pillow/install/with_pillow.log。另保存提供的三份实际父代理日志的安全副本，来源/SHA在review.json。

远端9eef Web job已有失败，但child artifact403不可取得，故不能断言本缺依赖是远端唯一或直接证明的根因。此处签本地实际平台缺陷及修复证据，不签远端CI已绿、Web已部署或游戏/美术质量。原17测试包含synthetic evidence fixtures，不冒称实际Motor/图像质量验证。没有运行Godot、修改生产源、查看或复制ci_9eef_*download.log的signedURLs。

审查冻结工作流SHA ffb77daf9fc735d01712783e98d22e6ecae6e71919662adef0204d8a8f5cac76。
