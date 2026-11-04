# PLAINS-DROP-RECEIPT-GUARD-02

本卡只迁移 `tests/enemy_feedback_01_formal.gd` 的旧掉落观察合同，不签生产表现、性能、整怪品质或完整CI。基线96bf4410的实际CI41001060607为100通过、2未通过、65未执行；正式反馈66检查中4条失败，森林80路线在原600秒内完成53条后超时。原失败不改签。

真实金币每帧保存运动状态，整份drops JSON在死亡后45/175帧保持字节相同的旧要求已不适用。六份实际诊断观察只发现units内七字段变化：age、bounces、position、rotation、settled、velocity、returning。仅这七字段允许运动；其余所有字段（含未知字段、单位顺序/身份/面额/安全锚、claimed、RNG与总额）仍全等。本场景没有拾取，完整claimed账本、钱包grants及balance必须不变；不凭空允许新结算。

原39处检查表达式、运行时66条旧检查的顺序、所有等待帧数、同图重载的完整字节相同检查、240秒原生/360秒Harness与60Hz不变。另读实际完整pickup池，核全部1/5面额单位、数量、总额、保存/实体对应、真实stage时钟/实例与Actor epoch；相对帧间隔约束年龄、碰撞次数及有限运动范围。恢复后stage时钟归零而掉落年龄保留，不能施加错误的绝对年龄上限。实际diver有4次接触且settled与returning可同时为真，不新增臆测上限。

新增反例只改观察副本：单位缺失/新增/重复、面额/总额/RNG/安全锚/未知元数据、非有限与错误类型、年龄/碰撞倒退、保存与实体同步的巨大有限位移/速度/旋转、幽灵claim、无账本领取、钱包重复付费/额外回执，以及非空历史grant删除/篡改。必须实际拒绝，不能只看旧成功标记。非空旧grant模型明确为合成副本；真实场景grants为空。

作者/root/corpse_contact_audit；独审/root/guard_review_recovery。首版漏放有限运动爆炸与幽灵claim，二版对恢复时钟约束过严，均保留拒绝/修正记录。精确候选SHA133c374ef037db27227dfe94df6d852416b67568786e6f8774239771697f8067已由root原strict wrapper实跑150/0；该次为dirty开发执行且没有独立嵌入完整输入清单，不能称Git clean或精确提交全量通过。后续Harness与独审证据分别归档。

最终selected Harness三项均fresh通过：正式150/0、身体掉落481/0、原森林80/80（541.165秒/原600）。正式检查17.665秒，原Harness内部完整source digest稳定守门通过；selected报告记录当前dirty四叶的SHA，不含两份独立完整source inventory。独审172项纯核对接受正式迁移，不签完整167或其他内容品质。
