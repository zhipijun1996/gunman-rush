# 平原怪物最终版本与交接

本轮按用户要求清理历史版本，当前工程只保留最终素材、有效工具和最终预览。分支 `art/plains-enemy-static-pr142`，清理基线 `2a6027e5c01fa555ee4faccb07303a8e1caab000`，交付于 [PR144](https://github.com/zhipijun1996/gunman-rush/pull/144)。战斗运行版本仍为 `efcd167fe3688d0dad71008a256b6c21ba938873`：本轮未改变运行逻辑或正式素材字节。

正式入口见 [素材说明](../../../../assets/plains_actors_142/README.md)。七类小怪的基础动作页与待机／移动补间页共同用于当前游戏，均保留；两 Boss 使用最终骨骼场景、固定部件与特效。牧风者的踏步转身、独立脚掌、前扑／后跳蓄力与穿身反制沿 [现行规范](../../../data/bosses/windkeeper.md) 和 [动作配置](../../../../resources/bosses/windkeeper_storm.tres)。兼容存档所需的恢复逻辑仍是正式消费者，不属于废弃版本。

已删除重复静态审稿、裁切中间图、拼版、失效的旧整身帧图播放器及静态对照工具。已批准静态参考的唯一生成源和哈希归并至 `assets/plains_actors_142/source/static/`；构建脚本只重建最终参考，十张 PNG 均逐字节复现。正式录制和专项共用 `tools/art/plains_actor_capture_base.gd`。检视器移除旧 Boss 帧图／光流选项，打包只包含当前资源及生成工具。

本地删除 608 个中间产物，移除约 5.4 GB 文件。`build/plains_actors_142/` 只保留最终十二段 MP4、检视页及资源、两种交付 ZIP 和 `evidence/` 中的必要验证记录。八个旧预览分支已删除，仅保留 `preview/windkeeper-motion-20261109`；源码提交历史由 Git 追溯。

本轮验证：CI 四项、文档检查通过；六个受影响专项（穿身、转身、连续性、Boss 行为、俯冲锁定、小怪帧绑定）通过；143 个正式资源文件与清理前逐字节一致。静态来源哈希、十四张动作页、最终包内容及十二段视频哈希通过。检视页 56 个动作选择／12 个视频入口无脚本错误，三段 Boss 短片在浏览器 1× 全程播放；软件解码丢帧记录不代表手机性能。证据见 `build/plains_actors_142/evidence/cleanup.json`、`cleanup-tests.json`、`cleanup-ci.log` 和 `browser-actions.json`。

唯一当前预览产物 `bfaf5f299902009db7cd23c5d7c451d50d313400`：

- [转身与扑击穿身对照](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/bfaf5f299902009db7cd23c5d7c451d50d313400/pounce.mp4)，约 16 秒。
- [一阶段转身与后跳](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/bfaf5f299902009db7cd23c5d7c451d50d313400/keeper.mp4)，约 19 秒。
- [二阶段实战](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/bfaf5f299902009db7cd23c5d7c451d50d313400/windmill.mp4)，约 22 秒。
- [全部十二段视频及来源清单](https://github.com/zhipijun1996/gunman-rush/tree/bfaf5f299902009db7cd23c5d7c451d50d313400)。

视频保留各自源码 SHA，使用明确的开场站位、生命阈值、宽镜头或指定招组夹具，不代表自然通关或最终平衡。当前无清理阻塞，后续迭代直接更新这些正式入口，不再并存审稿版本。
