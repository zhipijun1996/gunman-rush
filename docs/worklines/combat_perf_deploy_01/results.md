# 战斗热点优化与试玩交付结果

本轮已按授权部署，任务保持 **review：技术交付完成，待真机与玩家验证**。

[打开本轮试玩](https://zhipijun1996.github.io/gunman-rush/?v=506a4e40a1ee)。运行源码 `60f44fc1f0c41a3fab2fa6f6f641af3c63f20e50`（F），运行补丁 `70edb686`；prepared 提交 `f55e3cfc7d7867c672d76f5887fc3694c62502c8`。此次发布不表示合并 main。

八个生产文件仍由原 ItemArt／同伴查询／敌人反馈与变形表现所有者管理，复用原算法与实际消费者。未重生成或更换图声，未调整玩家物理、伤害、资源、奖励、随机或存档规则。style32／creative35 是实际源码的技术绑定，不是新艺术认可。

| 有限测量 | 原实现 → 本轮 | 范围 |
| --- | --- | --- |
| Release 暖 ItemArt 查询 | 4.55–5.19 → 0.057–0.063 ms | 非 editor 模板，三无人机五查询链，不含整帧/GPU |
| Root moving prepare+625 | 3.471 → 1.906 ms | 同进程核测量 |
| Root hurt/attack | 3.337 → 1.906 ms | 同进程核测量 |
| Root dying | 4.085 → 3.216 ms | 同进程核测量 |
| Root 首次构造 | 0.307 → 0.491 ms | 冷构造单次观测的代价保留，不作统计结论 |

这些是局部 CPU 成本，不能换算为手机 FPS、整帧 P95/P99 或玩家体感。原测量及独审保持原来源，见[既有局部证据](../../evidence/combat_perf_deploy_01/summary.json)。

最终 F 的实际交付链如下，原预算与检查集合未放宽：

- [CI 41382432305 / attempt1](https://github.com/zhipijun1996/gunman-rush/actions/runs/41382432305)：171 项全部 fresh、0 复用、0 失败（92+79），Windows/Web 与原 GPU/audio 步骤成功。CI 使用同次 prepare 的 56 个 generated Foundry 路径，不能称 runner Git-clean。Android 未请求，原 environment 的直接部署/公开验证主动跳过，后续单独走 prepared。
- 同 run 唯一 `gunman-rush-web-playtest`（artifact 13115684589）原 ZIP 440419078 字节，SHA256 `20e954b460d23c2ba834d2955f28201fd9a59d2150bc8a91e2d2ef4eb3469e95`。三项原浏览器共 73 项通过，耗时 155.401／226.419／133.197 秒，均在原 300 秒内；实际源码、ZIP、服务文件前后稳定。
- 实际 Web PCK 在空 cwd 用原 recorded-enemy 探针 13／0；无仓库资源回退。原连续动作影片第二次运行 2300 帧／38.366667 秒，固定 60fps、48k stereo，完整 SourceRoot 前后相同。是练习动作影片，不冒充自然地图战斗或手机测试；首次 preinventory 失败诊断仍留存。
- [Pages 41390679708](https://github.com/zhipijun1996/gunman-rush/actions/runs/41390679708) 实际检出 prepared P，重建并部署同包。公开 PCK 完整 216391560 字节／SHA256 `506a4e40a1ee711362f9f701b64f39ba68f9015c0922c102bf87ccc29dc74d59`，原公开验证器和独立 64 位流式 SHA 均通过，metadata 前后相同。
- 公开 GUI 实际 Title→Home→门 W→BEGIN→正式平原→移动，100.163 秒／原 300 秒；10 张实际截图经查看，Chrome 已关闭、源守门通过。runtime filter/page_errors 为空；保留 favicon404 与 Emscripten 主线程 blocking 诊断，不能写 console 全零。此 GUI 未执行战斗／死亡／无人机交互，也不代签审美与听感。

[精选交付索引](../../evidence/combat_perf_deploy_01/delivery/index.json)保存原收据、小日志和无损压缩原件；完整 ZIP／原 21 MB 合流报告／MP4 保留外部 canonical 路径与 SHA，不重复提交到 Git。旧局部 summary、失败和独审原文不改签。

剩余：实体手机 FPS/P95/P99、持续战斗体感、玩家认可及完整正式消费者 inventory 未验。质量卡 `consumer_coverage:null`，formal_integration 仍 unverified；技术/G4 通过不等于 G5。

回退公开版本可使用原 prepared `ab57c6d5cc14e279aa074f54fd1e0854ae97a750`（build `2e1274f62210`），按[既有交付守门](delivery.md)再次核实后执行；本轮没有触发回退。源码回退以 `e42b277f37425458a2920815258d1cfc817acfc3` 为批次基点，必须成组还原运行补丁、测试与技术绑定，不能只回退 GD 留新绑定。
