# Rendered / headless 输入时序：只读诊断

结论：当前A教程、旧growth和旧return的录像失败，首先对应**真实Router请求没有成为实际动作**，不能解释成关卡物理不可达。原Router按墙钟丢弃年龄超过100ms的排队输入，且不发rejected信号；自动策略却在提交请求时提前消耗最多6次尝试。真实原PlayerController小复现证明这条路径。原录像缺请求timestamp，故尚不能将某一项缺事件直接认证为已测TTL过期；需要受控录制/年龄观测确认。现在没有修改任何正式源码、timestamp、MAX_AGE、资源或敌人。

## 原始事实

完整逐帧/输入/shot/commit摘要和所有输入SHA见 `trace_comparison.json`。五个配对均确认同各自Seed/Manifest、19个driver字节、133个core字节及initial_capability；不是拿不同Seed替代失败。

| 同源配对 | movie | headless | movie失败bank内请求/实际accepted/打中该敌 |
| --- | --- | --- | --- |
| current A / base / map1 return | 316，policy失败 | 2287，目标到达 | tutorial：6 / 2 / 2 |
| old30f / base / map2 growth | 1873，policy失败 | 7576，目标到达 | area_2_1：6 / 2 / 2 |
| old30f / base / map1 return | 2830，policy失败 | 4711，目标到达 | area_3_1：6 / 1 / 1 |
| old30f / base / map1 fast | 2559，目标到达 | 2559，目标到达 | 末bank3 / 3 / 3，无无响应shoot |
| old30f / base/02 / map2 deep | 899，policy失败 | 899，同失败 | 不是录像独有失败；deep_high入口原敌/策略bank候选 |

current A 的具体区别：movie255的真实shot2→commit258使tutorial敌HP3→2；288的真实shot3→commit289使HP2→1。已接受弹的muzzle、projectile_direction、owner/event_id与伤害链完整，并非两弹全部偏射。movie284、285、286、287分别有sequence7、8、9、10的shoot_release记录，但没有accepted或rejected，cooldown仍0；288 sequence11才真正射击。六个策略attempt因此在仅两次实际战斗射击后耗尽，316提前停止，远未用满900物理帧窗口。headless284 seq7立即accepted/285命中，313再射/314终态。movie/player HP5、energy94.5不意味着敌已死亡。

旧growth、return也分别有4、5项无响应shoot，末bank所有实际accepted弹都有对应目标commit；这些raw同样没有排队年龄。不要把“有input_requests”当作已经送达Controller动作处理，更不要把缺事件一律写成AI瞄准失败或物理无解。

old advanced 的正确比较必须是`base/02`，不是base。其movie与headless同899、同deep_high入口unsafe recoil bank，实际跳跃/接触损血均有事件；这个候选应继续由内容/策略 owner处理，不能借TTL解释消除。

## 真实代码链

- `scripts/input/input_router.gd:102-141`：request_action将`Time.get_ticks_usec()/1e6`写入真实timestamp；consume_actions在下一Controller物理tick检查epoch与`now-timestamp>MAX_AGE_SECONDS(0.1)`，过期分支直接continue，然后清空队列，没有action_rejected信号。
- `scripts/player/player_controller.gd:63-75`：真实正常`_physics_process`递增_tick并消费Router；运动/资源均按实际物理delta推进。
- `tests/level_formal_trace.gd:149-177`：tick在await physics_frame之前采队列，在后续process_frame采结果；记录是“待送入”请求，不是实际consume receipt。
- `tests/level_formal_trace.gd:545-562`附近：kill策略在Router请求前递增_policy_attempts，以请求计6次，尚未等待shot_fired/rejected。不能仅把此数字提高来掩盖输入调度故障。
- `tools/level_visual_capture.py:42-58`附近：相同fixed60逻辑输入驱动，同时实际软件GPU渲染、截图及movie写盘。固定逻辑帧率不约束每帧墙钟；源和物理参数相同也不保证Router墙钟TTL相同。

另外，电影起始截图`capture_frame(true)`先await frame_post_draw再启动路线。current A controller_tick-trace恒为2，headless恒为1；第6 trace帧的机制clock分别0.133333和0.116667。初始cap快照相同不等于录像起跑时所有动态相位逐tick相同。当前教程的同trace telegraph238/attack266/recovery289及所有accepted命中不支持将这1帧差当主要失败原因；它仍是对照边界，不能重置机关或伪造clock来对齐。

## 已执行的三项真实TTL小复现

`router_ttl_probe.gd/.json/.log`是在ignored目录运行的真实Player场景fixture，正常Controller调度、原Router与原Motor；仅初始fixture地形/站位，不是正式地区通关。没有手动Motor步进、改timestamp或注能。

| 原Router动作提交时机 | 物理消费边界实际年龄 | 原真实结果 |
| --- | --- | --- |
| physics_frame信号后、原Controller消费前 | 0.000007s | accepted1 |
| process中提交后，真实OS墙钟停顿140ms | 0.140493s，epoch一致 | accepted0 / rejected信号0，射击精力未消费 |
| 先停顿140ms，再在physics边界走原request_action | 0.000010s | accepted1 |

三项使用同原代码，退出0，日志`ROUTER TTL DIAGNOSTIC: true`。第二项的自然精力恢复84.5→85不是假退款。第三项没有回写旧timestamp，而是在真实消费前通过原API提交新请求。这证明合法frame-bound候选可行，但没有实施到正式driver。

## CPU与录像条件

`cpu_observation.json`实读当前宿主：cpu.max=400000/100000（4核quota）、cpuset0-4（5逻辑CPU）、16GiB上限。cpu.stat累计15316次throttle/844443820µs是累计观测，不能归因某个旧movie；采样时未见活跃Godot，不能倒推过去并发负载。

原current A录像实际321视频帧、47.650s墙钟，约148ms/帧；capture.log原值CPU render均37.96ms、GPU41.75ms、encoding34.07ms，生成速度约正常播放10%。原旧growth约1879帧/105.98s≈56ms/帧，旧return2835/170.93≈60ms/帧。平均小于100ms不能排除局部尖峰；平均大于100ms也不能认证每个输入过期。以上是离线软件GPU采集条件，不是目标设备性能结论。原始未采逐输入timestamp，不能补造。

## 最小候选与复验成本

1. **优先只修生产执行条件，不改19driver/core。** 等所有Godot/原生/100图等CPU重任务真实终态后，由root协调仅一次当前A原seed/map1/return试验；明确`LIBGL_ALWAYS_SOFTWARE=1`与`LP_NUM_THREADS=1`，仍1280×720、60FPS、stereo48k。记录实际CPU quota、运行期间进程/节流、每帧墙钟、Router消费前实际年龄（可ignored只读monitor，必须另绑monitor源且标仪器化，不能冒充原observer）。不从重抽Seed或偶然一次目标到达推断原因。若目标到达且无未解释输入丢失，后续原生/图表与录像串行、同条件重采old/new正常影片；现失败全部保留。原80是原负载观测，不能与新不同负载归因内容；root计划的同条件serial both80另目录重采是合理控制。
2. **若受控录制仍会过期，才进入新真实scope修测试输入调度。** 将helper的测试意图在实际physics_frame、Controller消费前通过原Router API提交；完整覆盖jump/release/drop/interact/shoot，不能只增shot重试。以实际accepted/rejected/资源receipt区分请求与动作，transport失败另记，在原总物理帧/有限新请求预算内停止。不写Router._queue.timestamp，不改MAX_AGE/epoch，不注资源，不修改Motor/能力。需审计19个实际传递helper的请求点，显式新输入协议/策略来源，原v3/raw保留；driver变了必须同字节重采old/new完整cohort与两侧电影，不能复用旧80伪称同driver。成本高于单独渲染调度，先不实施。
3. 不因本诊断签内容公平/玩家成功率。旧advanced899和后续合法已接受射击仍失败的真实位置继续保留；正常可读预告、镜头、落点和趣味仍需实际影片/独审。

本代理没有启动任何额外movie或并行原生重负载，没有修改ROOT任何tracked/nonignored文件，没有写baseline worktree、host_response、loop、agent或质量卡。受控录像由root在heavy全部终态后协调；此报告不是该尚未执行实验的PASS。
