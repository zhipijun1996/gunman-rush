# 当前交接：D069 平原遭遇密度与地面反冲

分支feature/plains-branch-challenges；上一提交3eaa86d，继续[PR36](https://github.com/zhipijun1996/gunman-rush/pull/36)，不合并。上一轮发布及美术证据见[归档](archive/handoff_plains_comfort.md)。本轮运行提交为包含本文的feat提交，可用git log定位。

## 已实现

正式平原按公共路线/上下支路分配敌人，战斗房目标4/5/7、金币房3、道具房3/4；安全筛选不足时明确记录，不强行挤入落点与反冲区。独立encounters随机流、配置/实例/拒绝与版本进入RunManifest，可重放验证。新增巡逻草地模块；金币/道具守卫接入正式伤害与掉落，小怪存活仍可出门。样本首关选定路线2–3敌人，中后期3–5，不是全Seed保证。小齿轮从第2关、大齿轮从第4关进入两种蓝图，保留前后恢复台；服务关不加。

用户追加要求：地面反冲倍率0.65→0.55，名义605px/s×0.14s=84.7px，空中1100×0.14=154px不变，同帧跳跃射击仍按空中。普通速度260、平原一跳与慢时0.20保持。

权威：crossroads_density_reference.md、plains_encounter_density.md、plains_hazard_density.md。原作wiki请求403/402，未取得关卡统计，不冒称原作精确密度。

## 实际验证

Godot4.7.2.stable.official.ed1daf0bf，tools/godot.sh。核心5894/0退出0；完整29专项全部通过退出0，包含密度342/0、蓝图11721/0、正式生成4979/0。地面反馈28/0退出0。密度含金币/道具×地面/飞行守卫四条实际无伤Motor路线、真实弹体命中、段回退保留及活敌出口；蓝图含48条真实全路线/齿轮相位验证。不能把静态路径验证冒充所有敌人组合实机通关。

首次密度fixture未遇飞行敌人导致336/1，改为有界32Seed搜索并保留覆盖断言后342/0；失败日志保留。证据忽略目录build/verification/d069/{core.log,full-plains-final.log,ground-recoil.log}及encounter-density、hazard-density。文档/美术检查见后续提交记录。

## 正在进行与未验证

用户认可下一项射击风铃，独立样片正在开发；本提交不含风铃正式接入。用户允许按需子代理生成统一风格原创资源，表现不得改变碰撞。先完成独立样片、实际射击开门及同枪反冲验证，再接入Module Lab，不直接加入正式随机池。

D069尚未导出/发布；当前公开包仍为D068的1d76a1ca0509。完成风铃后整体Web、CI、公开包验证。Android/iPhone真机手感、美术、内容趣味性仍待用户验收；不声称已足够有趣。本轮Android未构建，Windows待本轮CI独立导出。
