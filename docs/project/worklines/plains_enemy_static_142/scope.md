# 平原怪物最终版本与交接

当前主游戏使用PR144最终怪物/Boss实现，与最新地图、镜头及手机工作台整合。正式源码直接维护，旧审稿、拼版、帧图播放器和中间产物已退役；历史留Git。当前整合检查见[交接](../pr_integration_141_145/scope.md)。

正式入口见 [素材说明](../../../../assets/plains_actors_142/README.md)。八类小怪按当前物种绑定：原扎根三铃造型归地面行枝铃哨，飞羽铃哨用新绘七状态×八帧单页；其余基础动作页与待机／移动页共同消费；两 Boss 使用最终骨骼场景、固定部件与特效。牧风者的踏步转身、独立脚掌、前扑／后跳蓄力与穿身反制沿 [现行规范](../../../data/bosses/windkeeper.md) 和 [动作配置](../../../../resources/bosses/windkeeper_storm.tres)。兼容存档所需的恢复逻辑仍是正式消费者，不属于废弃版本。

已删除重复静态审稿、裁切中间图、拼版、失效的旧整身帧图播放器及静态对照工具。已批准静态参考的唯一生成源和哈希归并至 `assets/plains_actors_142/source/static/`；构建脚本只重建最终参考，十张 PNG 均逐字节复现。正式录制和专项共用 `tools/art/plains_actor_capture_base.gd`。检视器移除旧 Boss 帧图／光流选项，打包只包含当前资源及生成工具。

专项使用当前场景的真实地面；未开放Boss/怪物房通过明确隔离夹具加载，不改变正式六房范围。动作、帧绑定、转向连续性、跳扑反制与动态动画导出均在整合版检查。完整主线、用户审美、平衡和手机性能另行验收。

Boss专项预览产物 `bfaf5f299902009db7cd23c5d7c451d50d313400`：

- [转身与扑击穿身对照](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/bfaf5f299902009db7cd23c5d7c451d50d313400/pounce.mp4)，约 16 秒。
- [一阶段转身与后跳](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/bfaf5f299902009db7cd23c5d7c451d50d313400/keeper.mp4)，约 19 秒。
- [二阶段实战](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/bfaf5f299902009db7cd23c5d7c451d50d313400/windmill.mp4)，约 22 秒。
- [全部十二段视频及来源清单](https://github.com/zhipijun1996/gunman-rush/tree/bfaf5f299902009db7cd23c5d7c451d50d313400)。

视频保留各自源码 SHA，使用明确的开场站位、生命阈值、宽镜头或指定招组夹具，不代表自然通关或最终平衡。三铃地空分种与P32远景的最新源码、局部验证和试玩归[平原交接](../plains_bible_v2_01/scope.md)。后续直接维护正式入口，不并存审稿版本。
