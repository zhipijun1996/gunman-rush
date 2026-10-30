# C/main整合源码独立审查

**限定接受源码冲突解决与测试迁移。** 精确源 `0d7ea6bf7df2eec5266b64012f677f288c2f6239`，父提交ab96fb27＋feb01068；726项只读核对通过、0失败。审查者 `/root/guard_review_recovery` 未编写被审源码/测试，生产作者root，Bible迁移作者corpse_contact_audit；本次未运行引擎、未修改仓库、未推送或重试CI。

GameAudio的main原方法全部逐字保留，唯一共改方法是六项voice metadata清理（保material_started与committed_reward）；B的材质伤亡方法逐字保留，完整方法集恰为双方并集。main四参数_play_original与递归调用、候选与COMMITTED奖励入口逐字保留。DemoApp与Git原始三方自动合并结果逐字一致。foreground、正式hurt选择读取和已选账本逐字等main。

双方全部check dict保持原值，唯一Bible-check inputs为有限并集追加；原167顺序完整保留，再追加主线audio-feedback，168＝92parallel＋76serial。原381个Bible输入前缀不动，追加41＝主线原缺14＋新27；三项重复来自B原前缀，未产生新增重复。审查者初始“全输入唯一”假设与该继承事实不符，已改为核对原重复次数不变，没有修改项目清单。原144/165摘要和原断言保留，并实际调用原lane-guard测试验证正常正例，8个独立内存变异（移除音频、移除怪物、旧前缀换序、新尾部换序、错argv、放宽audio预算、错lane、重复音频）全部被拒绝。

双方各11个归档条目逐件与各自实际父Git blob核对，未只相信自报SHA；两个原style21/creative24及完整原测试/源保留。新style22保持83角色与顺序，只更新App/Shop两项实际SHA，83条都与C实际源逐件一致。双方原测试方法全部留存：Bible35/35→40、creative13/13→17，原SHA字面量与每个原方法的assertRaises负例保持；当前真实纯测试由审查者运行planner22／0、Bible40／0、creative17／0。

这只证明冲突整合与有限守门迁移可接受，不是完整168、原生运行或affected通过。B的run41016649030失败仍有效；C还需精确新head实际检查。未代签艺术、听感、设备、经济、用户认可或G1–G5，996影片保持原源。

逐项证据 `/tmp/plains_main_C_review_proof.json`，汇总 `/tmp/plains_main_C_review.json`，实际脚本 `/tmp/review_plains_main_C.py`，执行日志 `/tmp/plains_main_C_review_pure.log`；三个真实纯测试日志为 `/tmp/plains_main_C_{planner,bible,creative}.log`。
