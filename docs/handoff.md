# 当前交接：D069 平原遭遇密度与地面反冲

分支feature/plains-branch-challenges；密度提交93bdc0d（基线3eaa86d），继续[PR36](https://github.com/zhipijun1996/gunman-rush/pull/36)，不合并。上一轮发布及美术证据见[归档](archive/handoff_plains_comfort.md)。本轮运行提交为包含本文的feat提交，可用git log定位。

## 已实现

正式平原按公共路线/上下支路分配敌人，战斗房目标4/5/7、金币房3、道具房3/4；安全筛选不足时明确记录，不强行挤入落点与反冲区。独立encounters随机流、配置/实例/拒绝与版本进入RunManifest，可重放验证。新增巡逻草地模块；金币/道具守卫接入正式伤害与掉落，小怪存活仍可出门。样本首关选定路线2–3敌人，中后期3–5，不是全Seed保证。小齿轮从第2关、大齿轮从第4关进入两种蓝图，保留前后恢复台；服务关不加。

用户追加要求：地面反冲倍率0.65→0.55，名义605px/s×0.14s=84.7px，空中1100×0.14=154px不变，同帧跳跃射击仍按空中。普通速度260、平原一跳与慢时0.20保持。

权威：crossroads_density_reference.md、plains_encounter_density.md、plains_hazard_density.md。原作wiki请求403/402，未取得关卡统计，不冒称原作精确密度。

## 实际验证

Godot4.7.2.stable.official.ed1daf0bf，tools/godot.sh。核心5894/0退出0；完整29专项47053断言全部通过退出0，包含密度342/0、蓝图11721/0、正式生成4979/0。地面反馈28/0退出0。密度含金币/道具×地面/飞行守卫四条实际无伤Motor路线、真实弹体命中、段回退保留及活敌出口；蓝图含48条真实全路线/齿轮相位验证。不能把静态路径验证冒充所有敌人组合实机通关。

首次密度fixture未遇飞行敌人导致336/1，改为有界32Seed搜索并保留覆盖断言后342/0；失败日志保留。证据忽略目录build/verification/d069/{core.log,full-plains-final.log,ground-recoil.log}及encounter-density、hazard-density。文档/美术检查见后续提交记录。

## 射击风铃已接入

主页DEVELOPMENT DEMOS→MODULE LAB→WINDCHIME TRIAL；见windchime_trial.md。实际两段练习：向铃A射击开门，再向井内铃B射击，可先开门再跳，也可同一发向下子弹开门并借反冲上升。通过两门到出口才CLEAR；不入正式随机池、不结算Run/Meta。暂停/回退清旧弹体与请求，回退保留已开门；死亡优先、Retry新尝试。新透明原创黄铜铃source/hash/region在assets/plains_v3/windchime_switch.json，门栅配色与A/B标记对应；碰撞不随素材改变，原20张v3源图不变。

组件29/0、实际App17/0，已注册core；最终核心5940/0退出0。Core验证时使用旧裁图，随后只换显示纹理/说明文字，物理未改，最终Web导出与GUI另验。29专项47053/0在风铃接入前完成；新风铃独立练习没有修改正式生成。全部结合版本由CI再验。

本地Web初版6a76ecd9ccfa，实际菜单截图6项通过含风铃，未声称浏览器自动完整风铃通关。查看截图后发现说明文字与门A编号重叠，已移到y245；最终包与公开结果后续追加。文档33权威97依赖、世界16区、旧92素材/13手绘/v3原20素材及新铃SHA均通过。

## 未验证与下一步

Android/iPhone真机手感、美术、密度与趣味性仍待用户验收，不声称已足够有趣。本轮Android未构建，Windows待本轮CI独立导出。下一项是按用户试玩调整风铃尺寸/节奏，再将已验证的射击机关做成有能力门槛、余量、镜像和安全落点的正式可选分支模块；不能直接把固定练习任意拼进生成池。新的敌人攻击AI与更多骨架尚未完成。
