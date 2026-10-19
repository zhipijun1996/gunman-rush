# Guardian campaign05：真实链限定CONTINUE，reader守门REVISE

不同作者只读复核，没有运行Godot或修改被审source。原capture SHA97ded5b760a3d417e9a2e649746f1cc70aa94905b4139ad8e7282fe50db69269；冻结reader SHAce99643f95c76480a92e888e5c19229cfb4f1b2337b0815460e17acc6fb07057；全部2010份snapshot库存字节仍匹配。独立脚本`review.py`与实际结果`result.json`在本目录。

原始数据支持这一次正式App消费者：实际debug只在初次固定v2/H入口；254帧正常fast到已开gate。pilot从实际未开战32HP进入，836个连续Engine物理帧每帧一Motor，34个真实Router queued请求。29个Boss Policy事件ID唯一、按事件顺序每次HP递减，且逐物理帧观测的Boss HP与同帧前累积伤害相符，32→0，普通子弹与真实移动铃反击均存在；玩家活着，Body完成2cycle、phase2、唯一defeat成立。源中pilot只提交Router movement/jump/H/shoot并观察App/Policy，无身体/血量/阶段/资源注入或手动Motor步进。

实际Viewport按下/释放539,436均在真实button Rect(409,408,260,56)内，暂停奖励后map1→map2。wallet0→12，HP4→5，stage ordinal1→2，stage epoch3→4，actor epoch3→5。schema2 RunManifest记录两图，map2后30个普通物理观测均alive/grounded。它是Godot Viewport事件，不是OS/浏览器真机点击；初次debug授H也不是自然平原通关。

**REVISE：现reader没有守住全部这些观察。** 独立实际调用其冻结validate函数，四个单独篡改均仍接受：删光combat.requests；所有combat.frame.boss_hp改32；两个pointer.point改[0,0]（矩形仍原值）；map2_normal_frames所有HP改0。四个恶意输入完整保存，未覆盖原capture。不能仅凭25checks/标志、final HP和pointer pressed序列签逐帧战斗/鼠标命中/图2活体观察；请作者增强reader并离线复核原件与负例，无需为已充分记录的字段重开native。

这不推翻当前原件的有限App链，也不是完整Boss公平、Queen整战、全部seed/路线、设备、视觉音频或区域深度准入。先前01–04真实失败与版本严格退出泄漏均不被本记录消除。
