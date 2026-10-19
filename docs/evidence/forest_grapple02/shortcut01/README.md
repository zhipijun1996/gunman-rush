# FOREST-GRAPPLE-02：恢复地面内部捷径反证

这是一个有限真实策略的反证及修复记录，不证明全地图所有无钩索策略均不可通，不代签真人手感或趣味。

## 原始反例

[原件包](original_proof01.zip)（SHA256 `3d65ce6aadbeb615457661c9ac7c460f7124d88c6e9e39f87f7b67f5b25e38d9`）含逐成员 SHA、完整原始 JSON、命令、日志和三份生产几何原字节。baseline01 在真实 DemoApp／InputRouter／Controller／唯一 Motor／完整敌人消费者上执行，无中途身体、速度、能力或资源注入：

- 真实 H→H→R→H 首段于171帧完成，之后钩索能力继续授予，但永不请求 H。
- 248帧落在宽 `thorn_mouth__recovery`；403帧正常持跳，415帧向下开枪取得向上反冲。
- 457帧完整24×36身体在 `middle_fork__crown` 实际支撑稳定12帧，跨过 lower_fork、thorn_mouth、middle_fork 三段主路。
- HP5→4，E86，射击次数落地按正常规则恢复；每个观测帧唯一 Motor 步进一次，原生退出0，音频正常释放。

baseline01 逐文件哈希与三份生产几何封存相等，但没有全仓前后 source inventory，不称全仓静默通过。baseline02／03 使用新增全仓守卫，虽原生各自同样完成457帧反例，均因协作源写入 **FAIL source_changed_during_capture**；原失败保留，不由后续成功改签。03 是发布静默消息与作者已获准修改深接收面的消息交叉，原始 manifest 仍为旧宽接收面，不能当修后反例。

## 修后有限反例

包内 fixed01 原生493帧、退出0、全仓守卫严格通过。相同驾驶规则在真实深接收面落地，仍于403帧跳、415帧向下枪；没有抵达 middle crown，最后在 `thorn_mouth__recovery` 完整身体稳定32帧、HP4存活后正常结束。它没有以超时、死亡或禁用能力充当“捷径被封堵”。当前更严格读者离线重验原件仍为零错误，但该结果不冒称后续恢复环坐标微调的最终同源运行。

## 读者反例与修复

原读者曾信任任意 `actual_shot_energy_credit/fired_airborne=true` 标签，容量内伪空中补弹能被接受。[原接受](forged_credit_beforefix.json)及[同变造修后拒绝](forged_credit_afterfix.json)均保留。本有限向下枪无命中策略现严格拒绝任何命中返还事件；这不改变游戏中真实敌人命中的正常返还规则。

新增 H 恢复读者按真实 Manifest 核对三个可停留环、请求方向与真实射程、cast/fly/pull/hang 逐帧状态、实体环接触点、静止挂态、连续身体位移、实心／荆棘碰撞及最终完整身体支撑。原先仅标签与数量的读者曾接受伪坐标／空锚点／伪钩头，已按独立审查反例修复；22个合成读者测试只验证守门能力，不是游戏试玩证据。[真实 recovery02 原件变造拒绝](recovery02_actual_raw_adversaries.json)亦只证明读者拒证能力。

正式新入口：`python3 tools/run_forest_vertical_shortcut.py --scenario all --output <fresh build path>`。它一次导入90秒，依次执行已证实捷径策略与实际 H→H→H→R 恢复策略，各自原生90秒，全程源守卫。最终同源原件与正常速体验证据以本目录后续原件及父记录为准；本文不将待运行命令写成通过。
