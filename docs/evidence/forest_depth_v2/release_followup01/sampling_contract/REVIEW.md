# Fan 浏览器采样合同：只读建议

范围：只读当前 `tools/verify_action_budget_browser.py:44–48`、真实0cf首次报告/events、ActionStudio事件生产与WeaponActionRuntime。未运行浏览器／native，未改Git、脚本或CI。当前结论是**原失败保留，根因未证**；不签“只是时序误差”。

## 原合同与实证

初次真实fire仍必须是向(790,590) move→down→40ms→up；随后原100ms再向(180,670) reaim/down。四项原语义不变：恰两blink、间隔≥.29秒、第二位移约84.7×.5且误差<1、首左次右。不能让后一按压／释放替代初40ms点击启动。

当前 `wait(totalblinks==2)` 返回值被丢弃；超时后仍mouse.up并立即取rows，可能把释放触发的新packet留到后续events才出现。这里有测量盲区，但不能据此解释为产品正常。

原保存events43..68实际有fan packet4：started tick1674，throw_windup同tick，fan_wait／blink1=1678，idle／blink2=1696；差18tick=.3秒。两个blink却均向右（150→222.967、222.967→259.451），不满足首左次右。原report四false、exit1保持。没有原输入调用/console接收时间账，不能从这些晚到事件确定packet4由初40ms点击还是后reaim mouse.up启动；最终有两blink不能反签原采样或原方向通过。

## 最小读者加严方案（尚未实施）

1. 保原两次输入的坐标、40ms长度、100ms重瞄时序及既有5秒观察上限。每个真实mouse API调用记录host单调开始／结束、console接收序号／时间；不要把host时间直接当Godot real_usec。装备/菜单关闭后实际状态需作为前置观测；不另加等待或重开练习把第一次失败换掉。
2. 在原reaim发生前的既定边界，明确要求初packet已被认可：唯一新 `weapon_packet/state=started`，weapon=fan_shuriken，detail.packet与envelope.packet一致，且有对应throw_windup／首blink。若此时没有观测到，记录启动未证并FAIL；不延长初hold、不加点击、不等它成功再开始100ms。若只是console传输延迟，只有独立时间证据才能判测量不足，仍不能当pass。
3. 后续只收该packet的两个真实weapon_blink，不能用整个 `events[n:]` 里的任意两个凑数。要求中途无新started、equip、practice_reset／会话转换；同packet具fan_wait→idle因果，严格检查原四项。当前事件没有独立session标识，不能声称packet数字全局唯一。
4. 原有wait布尔必须进入结果；timeout立即锁定本例失败，保全部events和当时截图。必要mouse.up只是finally清理，清理后新启动／新blink不得计入成功集合。成功也应先以同packet两blink闭合快照，再清理，免清理污染。
5. 重瞄必须在首blink之后、真实第二阶段采样之前到达Router。当前runtime每advance取实际aim_direction；host mouse.move完成本身不证明游戏已采样。至少用已有同packet fan_wait期间只读weapon_motion的aim（以及后续blink方向）证明新方向进入真实物理帧且早于第二blink；若现events没这条证据，应标未证，不根据期望坐标倒造。记录真实帧不放宽≥.29或距离阈值。

## 合法修复与隐藏bug的界线

合法：将忽略的wait返回改成失败；加初packet认可、packet关联、原阶段内重瞄证据；在原观察上限内收齐已经启动packet的完成事件；把失败cleanup与成功采样隔开。这些加强测量，不修改40ms输入成功要求。

不合法：把40ms改长、补点击／重复fire、启动不成功时先等几秒再reaim、第二次up启动后仍算初packet、扩大观察预算、把两个同向blink算重瞄通过、放宽原四阈值或只离线从最终events捞两blink改绿。若原40ms未启动或真实重瞄未生效，优先作为输入产品问题调查；不能以“CI慢”预判豁免。

本建议未完成根因诊断，也不授权实施或新CI。runtime_review唯一旁路时序诊断应单列source／输入变化／原失败，不能用诊断策略替代原语义验收。
