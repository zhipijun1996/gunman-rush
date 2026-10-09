# 人物物理

参数以 [player_tuning.json](../config/player_tuning.json) 为准。X 右、Y 下。普通速度与反冲速度分开；最终 v=normal+recoil。反冲添加 -I*d，指数衰减 exp(-dt/tau)。下落上限只限制普通竖直速度，反冲不被普通移动覆盖。

## 跳跃

有效接地后 used_jumps=0。第 N 次跳跃设置 normal.y=jump_speeds[min(N-1,数组末项索引)]，次数上限取 max_jumps。跳跃不清除竖直反冲，因此最终速度可能受反冲影响，列为试玩项。主动起跳立即清土狼资格。步行离开平台的土狼窗口内可用第一跳；窗口耗尽后将第一跳资格视为已用，余量取 max(0,max_jumps-used_jumps)。缓冲在落地后立即尝试，触发消耗一次且不连续重复。具体时钟边界与自动证据见验收记录。

## 射击计数

ActionResources 有 shot_charges 和 pending_ground_shots。空中成功射击立即消耗一次。地面成功射击受冷却限制，同时记入 pending_ground_shots；该帧保持接地则清账并维持满额；若射击导致离地，则新腾空剩余=max(0,max_charges-pending_ground_shots)。不得在起飞同帧被“仍接地”误恢复。

有效落地为上一帧空中、本帧有可站立地面且非主动离地。持续地面不重复发送 landed；侧墙、天花板不恢复。单向平台下穿期间不恢复。

## 碰撞

move_and_slide 后对每个碰撞法线，将 normal 与 recoil 中朝表面的分量各自投影消除；避免下一帧复活朝墙反冲。处理斜坡与多个法线。移动平台速度只由 Motor 统一处理，避免双加。

下穿只暂时忽略脚下单向平台，时间与恢复条件可配置；不得关闭全部世界碰撞。死亡后两种速度、动作缓冲、冷却和资源账本清空；重生到安全点并恢复默认资源。

射击与跳跃同帧先跳后射；新跳跃视为空中，消耗射击。完整顺序见 [架构](architecture.md)。高速弹体和危险区需要 sweep/segment 验证，不仅依赖离散重叠。

## 可配置能力

本文二段跳与两次射击是默认实例。实现必须符合 [能力组件](ability_components.md)，支持 max_jumps=0/1/2/3/N 和 max_air_shots=0/N，不能硬编码第三跳永远拒绝；跳跃速度数组配置与空中增减边界按该契约执行。
