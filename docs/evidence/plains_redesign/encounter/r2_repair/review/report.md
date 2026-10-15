# PLAINS-REDESIGN-ENCOUNTER-01 / round1 独立审查

Reviewer `/root/plains_spatial_audit`；implementer `/root/plains_encounter_worker`。我未实施被审源码、测试、卡或记录；全部审查原件只写本ignored目录，本结论只回当前真实review租约。Nonce `83b33532532c4e168ddb279b8ba795d0`，request hash `a79b00da22b146151ff37f90bd11a2c288e4087d4bd2e31fe6a47419ab212777`，source digest `8ccb861adce6bfa86a21c35f8d131be5c8693c97819391356d22741b813f4edd`；实际3600秒deadline为 `1792041521.5015829`，结束前源仍逐项匹配。

**REJECT G0/G1技术过程准入：ENCOUNTER-R1、ENCOUNTER-R2。** 真实敌态/射击/回退的主要运行证据成立；拒绝原因是原Harness漏执行新增回归，以及实际领奖经济因果校验有可复现漏洞。不是将已保留的deep_high内容失败误当捕获失败，也没有用未到阶段的趣味/画面/设备证据泛拒。

## ENCOUNTER-R1：原Harness入口跳过新增测试（中，高回归风险）

`tests/test_level_formal_receipts.py:156`和`tests/test_level_experience.py:146`在文件中部调用 `unittest.main()`，新class分别在159/149行之后。原 `tools/harness/profiles.json:503-525`实际命令仍是 `python3 tests/<file>.py`，main会在新类定义前执行并退出。

Reviewer独立真实执行，source同字节、每项exit0：

| 同一文件 | 原Harness直接入口 | discovery全部类 |
| --- | --- | --- |
| test_level_formal_receipts.py | 11 tests | 16 tests |
| test_level_experience.py | 15 tests | 21 tests |

实际controller fresh日志同样只有11/15。作者手动discover16/21真实通过不等于原生产入口覆盖。被漏的是新增完整basis/未知模式/runtime inventory、Motor与传递driver compare，以及shot receipt时间/session/epoch、晚死亡不豁免早hit退款等11项新回归。

最小修复：把各文件唯一 `unittest.main()`移至所有类定义之后，或把原Harness命令明确改为等价discovery；保留全部旧测试/断言。实际通过原Harness调用验证至少全部当前16/21（R2新增后更高），附准确计数和日志；不得只换成功摘要/测试数字或重复手动discover。

证据：`entrypoint_reproduction.json`、四份*.original_harness.log/*.all_classes_discovery.log。

## ENCOUNTER-R2：claimed布尔与choice匹配替代实际经济效果/收据（高）

位置：`tools/level_experience.py:226-234`。当前校验仅约束local claim_output.choice、最终claimedID、唯一modal submission、grounded位置；没有约束所选资源/金额、真实交易receipt与before/after效果，也未把local输出与最终正式RunManifest cache输出对应起来。

取当前controller fresh的**真实**新图map2/growth原件 `run_h65v_l8t/after/case_2/capture.json`，原件完整通过 `validate_capture`。其中medium_0为原ResourceRewardChoice coin16，实际钱包2→18，medium_1为coin16，20→36；原始receipt确有对应唯一run-prefix/chest/resource=16，没有假领奖。

Reviewer独立对同一真实capture只做一个字段变异，其余真实events/frames/claims/manifest保持：

1. `actual_cache_claim.wallet_receipts={}`：仍接受。
2. `actual_cache_claim.after.coins=before.coins`：仍接受。
3. `actual_cache_claim.claim_output.amount=999999`：仍接受。
4. `actual_cache_claim.claim_output.resource="imaginary_resource"`：仍接受。

这是**验收器伪证可过**，不是声称游戏原生真的发了999999币。现有正常App领取/queued错误拒绝/重复领取真实证据不能替代这条因果守门。

可直接复现：

```
python3 build/plains_redesign/review_encounter/reproduce_claim_neighbors.py
```

实际exit1：四个应拒反例全被接受。脚本/日志/process JSON和压缩的原始真实growth capture已在本目录保留；后续可解包 `reviewed_original_source.tar.gz`，用 `REVIEWED_SOURCE_ROOT`重演被审版本，避免修复后丢失原REJECT。

最小修复：记录并核实际选中的ResourceRewardChoice/真实offer快照→正式cache输出→对应唯一wallet/HP/meta实际transaction receipt及before/after效果。local claim_output须与 `formal_run_manifest_final`中正确stage/chest的真实cache输出一致；不能仅choice字符串相同就接受任意resource/amount。兼容item路径的真实RewardService/build变化或明确该证明只接受记录过的合法资源路径；不能删合法coin/heart/note选项规避。

不要硬编码coin16、当前chest ID或简单要求钱包净差恒等amount。应从真实候选/服务结果导出金额，正确处理合法夹紧/满血替代、同帧其他自动coin/交易和幂等receipt；验证各自before/after和receipt集合变化。补四个原始变异、错stage/错chest输出、错/重复receipt、heart/note及合法夹紧正例；通过**原Harness入口**运行。保留真实wrong UI choice虽queued但未claimed、重复领取不重复支付的native正反例。

## 已独立验证的成立部分

1. 完整解析当前request/prompt/六fresh checks、API与冻结源。233 portable成员压缩SHA/解压SHA/长度全部匹配；689文件source archive每成员逐字节等于当前文件；当前controller source_before==after==当前684 runtime capture inventory；lease digest匹配。原index/source tar精确副本已存本ignored目录并记SHA，原失败没有覆盖。
2. **Reviewer亲自fresh实际执行**原native14项fixture51/0，2.595秒；原normal DemoApp pit/UI/retry16/0，7.820秒。真实Router射击、阻挡墙/冷却/合法耗至零后空中拒射、三commit终态、dead无再退款、living/ineligible/telegraph/attack/recovery与移动身体均不是JSON标签。没有重跑整套8capture。
3. **Reviewer独立native物理负例**：ignored脚本继承原fixture，删实际墙StaticBody后沿原输入射击；原occlusion保护确实失败，HP3→2且1个真实commit，expected exit1。不是只改JSON让测试失败；源码没变。
4. 当前shot→真实projectile→APPLIED费用→DamagePolicy commit→clamped hit退款比准备阶段更严；独立对真实capture改费用/退款时间、session、epoch、APPLIED、amount/orphan与“较早hit缺退款但后来死亡”共10邻接，全部拒绝。准备风险P-R01已修好，不能沿用旧静态风险作新拒绝。真正同tick/同actor_epoch死亡退款取消由新增unit正反例验证，但R1当前使原入口漏它们。
5. 19个driver传递闭包逐项更改均拒；Motor/input/build/stamina/实际shoot/recoil core删改拒，漏项目/Scenery/generator完整runtime绑定拒；合法每侧Scenery来源差异可通过。8份paired receipt逐项source/命令/log/frame/hash验证无错；两侧19driver+133core字节相等，各552 runtime项保留各自真实内容。实际两侧Scenery源码恰好相同，不夸成实跑了画面差异；合法Scenery变形是校验器测试。
6. 原真实paired结果保持old4/4目标、new3/4目标；新map1 return在deep_high入口diver接触tick789、策略停止816，`captured=True`只意味着证据有效，`route_policy_failed`仍是失败。frame截断不同，不能以总interaction/候选数少推趣味改善。
7. 逐paired核initial/final能力：8例equipped weapon、build、tuning、跳数/射击上限无改变，实际选择是coin或note ResourceRewardChoice；变化只有shot_energy.current和combat_energy.current等动态余额。没有因initial相同就假称整路资源恒定。compare只绑定initial，未来item/build实际改变须另报，不得静默当同能力。
8. damage_committed按target分开；当前新growth的总提交含打敌伤害及一次player受伤，不能将总数当玩家受击数。`paired_analysis.json`保存逐目标计数。
9. 真pit恢复ENVIRONMENT commit与segment_returned同tick1595、HP-1/session+1/actor epoch+1，原scene/敌实例保留、开门/已领奖/钱包保留；enemy进入recovery/旧攻击取消属于原合同。before energy80→returned80.5是自然恢复，冷却从0.25经真实时间变0，不是免费重置。随后原输入到真实well出口，safe_trace仍标失败回退范围。没有把fixture取消攻击当关闭敌人，也不签所有锚点/所有地图。

## 最小返工与复审范围

先修R1入口和R2完整资源交易因果，两项同一窄返工包即可。不要改Motor/资源/AI/生成/保存、old默认命令或旧raw。保留本REJECT/source/index/原233成员与实际所有失败；新证据写新round子目录。旧4/新3内容结果不因为校验器修复重标成功。之后原6checks fresh，原入口实际收录全部测试，必要native/UI与真实资源路径重新验证；同源不受影响的8capture可精确说明复用，不能伪称全重跑。

全局调用计数、原loop历史和28上限由root管理，本审查未启动loop/agent或修改记录。独立G4不能由作者先签。最终dual80/cohort、正常音画、HUD/可见预告、遭遇内容公平、整区趣味、美术、性能和实体设备仍未验；本REJECT仅针对G0/G1技术验收缺陷。
