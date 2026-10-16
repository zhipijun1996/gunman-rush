# PR69 生产能力修复：真实结果与未达目标

基线 `4f2066fd610faa1b86de5a942fa7c1c0bdacda26`，分支 `feature/production-capability-repair`。不合并 main。本页为源冻结前检查点；最终源提交、完整构建和公开发布以随后真实记录为准。

## 审计结论与有界生产结果

[独立 V3 审计](../../evidence/production_capability_repair/v3-audit.md)逐项覆盖 44 个原生产请求、14 次图生与全部有证据的失败/交付。实际取得 33 个原 response、27 个宿主 elapsed；其余逐条标未知。V3 最后本地 deliver 为 57.68 分钟，其中 gameplay/art 43.23 分钟；最后发布失败，未上线。模型宿主 elapsed 包含内部工具及等待且互相重叠，不是纯模型成本。

主要瓶颈是生成素材与真实消费者接口不匹配、根/完整轮廓晚验、空间与敌人各自拼装、旧版本消费者和稀疏证据晚暴露、昂贵回归后的生命周期/下载/发布失败。不是图生调用次数本身：V3 可见 13 次图生工具 wall 合计 636.724 秒，首次 RootBell 精确 API 时间未暴露。

本轮限定两家族、两现有空间，最多 4 图生/每族 2 轮，实际 3 次（工具 wall 合计 193.8 秒）。两次岩壁都未达原目标，停止且没有消耗剩余调用继续追图。没有全平原改造、没有调低商业手绘目标、没有把小装饰放大或几何占位当新手绘。

| 实际产物 | 正式结果 | 仍失败/未验证 |
| --- | --- | --- |
| 自然岩壁连接家族 | 原图、冻结合同、24 格接口校准、连续母版校准和实景失败均保留；失败方向从运行消费者与三个 export preset 排除 | 第一轮 24 格 gutter 全失败；第二轮 core 0.984501 < 0.995，有限周边采样仍有直切/矩形轮廓，缺专用内凹连接；**完整连接与商业品质未完成** |
| 有根中景植物 | 一次 AI 原图，6 个完整来源区域/根锚/等比缩小校准；真实静态石台支撑 solver 接入；独审准入当前 2 树 + 1 灌丛的有限实景用途 | 原等分 margin 合同失败照留，不追认；六件均有源校准不代表全部正式消费者或商业验收 |
| RootBell 联合空间 | 保留宽岸双齿轮，新增 560 宽恢复桥紧岸，复用锁标定点脉冲/射击打断/跳过活体；同一合同给出相邻动作、退路、返程、植物 keep-clear；总敌数/概率不变 | 40 图专用语料 1/40→2/40；原交付 20 图语料 **0/20→0/20**，常见路线覆盖仍未解决 |
| 真实玩法/像素证据 | 两段正常速度 60fps 正式 DemoApp 影片，宽 114.717 秒、紧 86.417 秒；独立实际查看宽 16 帧/紧 14 帧的连续动作窗口，有限默认准入两类/当前植物用途 | 没有全片播放/听音、整局通关、商业全区审美或实体设备签字 |

植物 PNG 的纯美术 A/B 来自冻结 v11 宽岸，同 Manifest/几何/镜头仅 toggle 新植物；不是 v12 A/B。v12 的实际影片与 fresh 默认运行另有独立证据。

原影片每片实际为 **17 个 Router 动作 + 1 个生产 pause callback + 1 个 inactive 生命周期夹具**，不是旧 raw 标签里的 18 个 input-only。各片活体低资源完整去回确实起始能量 0、无开火、RootBell HP3/玩家 HP5；inactive 夹具阶段均有一次 HP5→4，不能宣传 19 case 全程无伤。源 overlay 与原片指纹保留；后续仅开默认 gate，不把候选影片改签为默认运行。

## 缺陷修复及严格边界

| 问题类别 | 真实定位及修复 | 验证边界 |
| --- | --- | --- |
| 原远端 terrain 失败 | 该次内部日志未上传，原精确根因仍 unknown；保留阶段/内层完整 log、verbose、超时与 failure reason | 后续新有效 CI 才能证明当前发布修好，不能从本地 Ogg 倒签历史唯一原因 |
| Ogg 实际退出缺陷 | fixed-fps 快速退出先于音频后端混音线程释放；weak playback tracking + 有界 shutdown drain，正确 teardown await | 真实 Ogg 正例 clean；跳过 drain、强保留 playback 负例拒绝；不是固定 sleep 或降低 ERROR 门槛 |
| 独立 ObjectDB/type-loading 缺陷 | 原入口纯 load 即 21 ObjectDB/18 script resources；仅 pin 历史夹具仍失败，仅局部显式 cast 即 clean | 原断言/await 保留；外部最小复现可证，Godot C++ 内部所有权细节 unknown；与 Ogg 不混因 |
| 严格资源诊断 | 相关 terrain/plant/space/ecology/audio wrapper 拒绝 singular/plural ObjectDB 警告及 resource ERROR，即使 native exit0/功能断言成功 | 真实仅一个未入树 Node、native0/无 ERROR 的日志仍被全部相关 guard 拒绝 |
| 网络与工具链 | absolute toolchain cache、同 SHA 部分下载 Range 续传、锁/校验/隔离/原子安装；只有限重试 transport/5xx/429，403/hash terminal | 真 curl28 在180秒留下1,147,880,236B，续传23.596秒完成；全安装217.618秒、暖检0.128秒。旧实现210.119秒终止未完成，不伪造速度比 |
| 发布恢复 | checkpoint 写前持久化，绑定 ref/SHA/run/attempt；恢复不 redispatch，不自动重跑 CI/auth；验证 deploy/verify_public、API artifact digest、实际 PCK/hash 与公开指纹 | 13 项实际隔离测试；旧189MB远端ZIP真实流验及错digest/source负例；旧 run 仍失败/未部署，不能借旧归档签新发布 |

## Harness 的实际改进

依赖解析使用实际选定任务/命令/知识与原质量证据，缺项在派工前阻断；精确 SHA 物化后才继续。任务依赖失败只阻断依赖链，不把无关家族挂在失败岩壁上。预算按真实任务 cap 和失败方向停止，保留独审/发布时间，不以耗尽调用为成绩。

验证先受影响短专项，再一次完整适用交付。缓存同时绑定源/命令/工具链、完成标记、归档产物和实际 live 输出；删/改产物或链接祖先都拒绝复用。原断言未删降，新增反例证明真正的失败边界，不以测试数量充当产出。

原 `production_loop` 实际两租约调用完成连续源校准工具任务，由不同代理只读审查；终态相同命令 resume 新调用 0，源漂移实际拒绝且 calls 不变。原 core 校准仍 exit1、content_complete=false；工程 stage ACCEPT 没有升级原美术合同。原件见[真实任务与效率报告](harness_report.md)。

一次受影响 Python 短检查被源快照守门正确中止：分享 MP4 尚在 docs/evidence 写入，源变化。它是本轮调度失误，不是测试断言失败，原件/时间保留；写入全结束后才冻结并跑完整回归。

## 交付与成本记录

当前 frozen-runtime 的 terrain/all-maps、connected-family 与真实 Ogg 生命周期严格专项已通过；两 fresh 默认、真实 /tmp 40 图、旧 165 断言与旧版本 G1 严格退出也通过。最终完整 deliver、准确源 Web/Windows、远端 CI/公开 PCK 指纹仍待本轮实际完成，不能用专项或旧构建代签。后续原始结果将追加准确命令/源/构建/发布链接。

阶段区间报告区分模型实施、图生、实际集成、验证、独审、返工、网络等待和发布，重叠使用 interval union，不相加成伪墙钟。工具不可见的 tokens、价格、图生具体 model、纯模型实施/内部独占网络等待写 not_exposed；租约包络、进程耗时不冒充纯推理。最终效率比较以合法资产用途、实际空间判断、完整交付耗时与发布结果为单位。

商业岩壁家族与全域手绘标准明确未完成；玩家趣味、整片音轨及实体设备未验证。任务保持 review/in_progress，不按技术通过标 content done。
