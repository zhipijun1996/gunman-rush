# 连续世界重建候选：本地试玩交付

Linux x86_64 试玩包（历史本地产物路径：`/tmp/plains_world_rebuild/delivery/build_01/plains-world-rebuild-candidate-linux-x86_64.zip`；当前环境未验证可取得），266,160,601 bytes，SHA-256 `dac8689451ae4ee37dde13b3d1b68fae54aaa1b98a4e3dfd1bf3dbb27ee2bf2d`。冻结运行源为 `ba787df7261dba40f75409a3b99457dd9bbef985`。该 `/tmp` 产物当前可取得，不保证环境重建后永久保存。

解压后运行 `./play.sh`，默认布局0；运行 `./play.sh --variant=1` 切换另一结构布局。A/D 移动、空格跳跃、鼠标瞄准与左键射击。保持真实 PlayerMotor 与战斗输入，不写存档；手动入口无自动驾驶。

两种有限布局的内部独审结论为 **ACCEPT_SCOPED**，不代表用户审美认可、完整随机平原、商业品质或设备认可。两个布局共享四张绘画 PNG，不证明任意随机 Seed 均可用。包内版本说明与项目独审03/04分别保留这一边界。

严格打包实际通过：

- 复用历史保留 producer 的当前资源清单与 `PCKPacker`，以及现有 `Pack` 字节读取、`harness.run_check` 严格退出检查。未修改 `project.godot`、正式入口、主分支或森林文件。
- 当前原始源与导入资源形成1529项 PCK输入，全部包内字节逐项 SHA-256 对照；PCK 为195,286,928 bytes，SHA-256 `f330b40335c4cc812a76bceb993b02af368bef5970be7af7025e046637da76c2`。未复制旧 PCK。
- 空工作目录 headless与GUI启动均通过，实际 `get_world_rebuild_snapshot()` 与 `/tmp/plains_world_rebuild/render_layout0_final/frames/receipt.json` 完整相等：3个碰撞体、1名敌人、实际绘画消费者。没有使用旧 environment/regional 字段冒充新消费者。
- 正常1280×720包内GUI截图保存在 `actual_packed_gui.png`；严格Godot错误、退出释放与源前后指纹检查通过。ZIP 全成员CRC和内嵌PCK SHA复查通过。启动通过不代替路线通过，路线录像另见本轮证据。

引擎为 `4.7.2.stable.official.ed1daf0bf`。GUI smoke 使用云端软件渲染与 Dummy 音频，未进行真人、手机、手柄或实际听音验收；用户 `play.sh` 使用正常设备。Godot许可随包保留；新图像模型与商用许可未独立确认，不声明商店发行授权。

包内 `version.json` 保留实际执行命令、进程耗时、日志指纹、源指纹、PCK与GUI指纹；`logs/` 保留原日志。恢复适配脚本保存在包内 `recovery/prepare_bundle.py` 和 `recovery/finalize_metadata.py`，以及 `/tmp/plains_world_rebuild/delivery/`；前者需冻结源与真实GUI报告才能执行，后者只补准确限定说明并复查ZIP，不改已验证运行字节。大文件全部保存在 `/tmp`，未进入正式资源池。
