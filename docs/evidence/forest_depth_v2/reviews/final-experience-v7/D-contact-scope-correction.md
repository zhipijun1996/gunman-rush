# D04/D06出伤绑定缺失：追加撤回受伤/公平范围

作者后续盘点发现overlay新增NPC未注册DemoApp的正式`_enemy_contacts.append(_contact(...MONSTER...))`。本人现实际重读原04 overlay begin：绑定了NPC Damageable/Actor/Policy，加入enemies，却没有该出伤Emitter。`EnemyActor.bind_encounter`不补这个独立消费者。既有Player受敌伤来自`DemoContactEmitter`（Node2D相对身体扫掠），不能因NPC是真CharacterBody或可被H伤害，就推导它能伤Player。

因此本独评D04/D06中“Player实际HP一直5、仅原心变6”仍是原始记录事实，但**撤回用该HP记录支持完整敌人无伤、公平性、两法风险相同或不同的结论**。D06同tick288 ordinary进展/E优于04H仍是原输入/资源反证，不是完整战斗价值的有效比较。原H/body/kick/R、NPC受伤Policy、真实奖励/出返、普通1R失误catch/低岸恢复、source guard与退款观察仍各保其范围；不追签缺失的NPC对Player伤害。

完整出伤绑定、真实受阻有界落地恢复属于新源，必须新同前缀强对照，不能把原raw重标通过。作者scope-correction.json保所有04/05/06/07原件SHA与失败链；本人未改这些raw/旧审计。07虽真头/身体/左kick/R，但215实体受阻导致native失败，不签闭环。S整区REVISE保持。此追加说明优先于任何把旧相同HP解读为完整无伤/风险认可的段落，技术通路不能代签正式消费者完整接线。
