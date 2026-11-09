# 平原 Boss 当前交接

用户已确认现有美术。本轮在 PR144 保留三阶段，采用用户指定的牧风者生命值，加快接近、连招与收势，扩大并加快扑击和后跳；关键反制为迎向 Boss，从高抬身体下方穿过。数值唯一来源为 [健康资源](../../../../resources/bosses/windkeeper_pressure_health.tres) 和 [动作资源](../../../../resources/bosses/windkeeper_storm.tres)，行为归 [牧风者规范](../../../data/bosses/windkeeper.md)。

分支 `art/plains-enemy-static-pr142`，起始基线 `f0966cd1486a0c494293156ad47c873c68c7c21f`。运行源码 `4d83cc4b3bd9048c52e5669abb50798b290220b1`；后续仅回填交接。运行改动为生命与动作资源、起跳前落点锁定、真实身体弧线和阶段三跨台速度；配套专项、录制与打包工具同步更新。七怪、巡游机与所有已批准原生素材保持原交付。

地面扑击在前摇开始时锁定落点，落点略越过玩家原站位，起跳后不追踪改向；前方空间不足时选其他招组，避免靠墙变成贴地短跳。真实接触判定全程保留。后跳沿真实平台验证支撑、保留冷却并在落地后继续原招组。三阶段仍依生命分界推进，二阶段风车与广域风压、三阶段断桥及真实平台移动沿现有状态主人。

实际检查：CI 四项和文档检查通过；十个受影响专项共 2347 项通过，包括穿身／停留对照 36、转向与后跳等 75、连续性 506、Boss 行为 25、牧风者时钟 1198／几何 97／支撑 78／正式 App 63／奖励 139／音频 130。真实固定世界 P-R14 使用原 Router、PlayerMotor、健康与接触策略；等待出生保护到期后，两个方向普通地面移动穿身均无伤，原地停留均受伤。跨台测试因提速暴露原夹具反应过晚，改为普通行走至内缘并在锁定预告时起跳，仍要求玩家在 Boss 空中换台、落点锁定、空中恢复及最终真实支撑；未改变玩家物理或关掉伤害。

三段新片完成 1× 浏览器全程播放，检视页 56 个动作选择／12 个视频入口无脚本错误；12 段公网 HTTP 与 SHA256 校验通过。新片 H.264 Baseline／AAC、540p60、faststart，每段约 1.2–2.4 MB；浏览器软件解码分别丢帧 0／1／0，不代表目标手机帧率。保留九段既有小怪／巡游机视频及其原源码 SHA，三段新片绑定本轮运行源码。

- [一阶段：接近、扑击与接招](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/5da8e8b8ece526c6211ec28df2bdd0bc4ad04ab1/keeper.mp4)，22 秒。
- [二阶段：扑击、风压与快速后跳](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/5da8e8b8ece526c6211ec28df2bdd0bc4ad04ab1/windmill.mp4)，19.2 秒。
- [双向穿身／停留落点对照](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/5da8e8b8ece526c6211ec28df2bdd0bc4ad04ab1/pounce.mp4)，11.2 秒。

实际观察中高跃身体与地面玩家有清楚空隙，二阶段头顶风车完整保留，后跳脱离贴身位置后继续攻击；身体尺寸保持一致。审查镜头为固定倍率宽镜头，开场位置、二阶段生命阈值与穿身对照指定招组为明确夹具。证据为 `build/pounce-ci.log`、`build/pounce-check-results.json`、`build/pounce-support-debug2.log`、`build/pounce-comparison.log`、`build/windkeeper-pounce-142.json`、`build/plains_actors_142/browser-actions.json`；录制／打包入口为 `tools/art/capture_plains_actor_combat.gd`、`tests/windkeeper_pounce_142.gd -- capture`、`tools/art/package_plains_actor_mobile.py --pounce-master`。这证明限定反制与动作，不代表自然通关、全随机招组覆盖或最终整体平衡。

当前无本轮运行阻塞。交付于 [PR144](https://github.com/zhipijun1996/gunman-rush/pull/144)，下一动作按用户实际战斗反馈继续迭代 Boss 招组与难度。
