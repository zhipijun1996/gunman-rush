# R3-CURRENT-CONTENT-CONTRACT-01 外部候选

此包是当前 PR122 内容的测试输入/覆盖合同迁移，不是保持测试语义不变的重构。旧 CI-CONSUMER 原278无伤承诺及所有原失败不改签。原 full all 平台诊断和修正后的实际 shot attribution 已有单独成功证据；本包提取共享 helper、默认路由及新增组件消费者必须重新独审/原生，不能沿用其 PASS。

实际写集只有两既有工具/test consumers、原component、一个test-only helper及UID和现有profile输入。pilot只采用已验证 a77017e1 原字节，无新导航。helper不保存App或节点、不构造地图/碰撞、不管理玩法状态。真实两个消费者为原完整capture与原R3组件脚本新增first-group正例，均使用真实App/Module/PlayerMotor和同pilot。

共享helper：
- `create_formal_app(tree)` 保原App.new →禁meta持久化→root.add_child→start_plains固定seed→原8帧。
- `place_initial_entry(tree, app, boss)` 保原唯一初始reset与5帧；调用者先绑定实际生命/伤害/发射信号。map2原load_stage fixture仍留原capture位置，不偷换自然过图含义。
- `platform_observation(stage, player, controller, encounter)` 提取原真实shape/slide数据读取，不创建碰撞规则。
- 只读观察实际presentation_event、ShootAbility.shot_fired与Damageable.damaged；`validate_first_group`/`validate_full_fight` 共用唯一原四源shot_id/event_id join。私有预期只由两命名入口固定2或40；first也要求2唯一真实发射、2真实命中/1伤、实际容量40→38且非terminal，不跳过身份/HP链；full仍40→0与原全部终局证明。

原component flat输入：站立150、晚跳等待68+持跳右行78完整保留；原晚跳在采用的上钟实体接触下作为真实损血负例，新增policy.source_id确证来自原body emitter。原“held base jump clears actual full body roll”正向义务在真实App低台基本跳 case继续断言，且由完整支撑/腾空/跨越/落地/整个组0真实结算/两发两命中证据共同支撑。不能把只改负例称成功迁移。

原capture当前map1默认all，原wrapper不加参数就会消费；map2 Pressure原分支不变。`--platform-counterplay=off` 明确保留旧导航诊断，旧失败不预期通过；`first`用于显式诊断/组件，共用同一动作流程。原25失败谓词、原40HP/1伤、7200/180、两枪上限、相位/奖励/自然输入/碰撞不变。

profile当前full185及95+90不改。原underworld-continuous-bosses 37个inputs按原顺序保留；原tests/underworld_plains目录已涵盖新增helper，不重复添加。仅补原实际读取且此前缺闭包的Bell与Pressure两个pilot及tracked UID。原Harness360、各native180、成功marker、权重、serial/cacheable和wrapper全不动。

待独审后由root执行：原component（含新增first）、原roll-only（含两个原flat动作和新正例）、原完整wrapper --full-fights默认map1/map2；检查同源、音频清理和严格退出。不得因新case超时提高原180/360。公开网页、GUI、设备、公平性全局结论不在本包范围。
