# PLAINS-TERRAIN-03：正式消费者漏检与返工

基线 main db1a27ef2778405908c91a54f9c02699684884e9，分支 fix/one-way-platform-boundaries。目标：纠正正式单向平台的端头裁切/内部端帽，并让证据范围约束交付声明。复用 art-director、game-quality-gate、gameplay-reviewer 方法及 project-integration。实现者自检，独立审查未执行。

## 已知失败与根因

用户手机截图实际指纹 f6134e79；地址的 v 参数不等于包指纹。截图区域 ABANDONED CLOCK COURT，木藤单向平台中部反复出现完整铜环端头，物理左右端裁断。此前 stone gallery 及入口画面没有覆盖它。

正式调用链：PlatformingModule._draw → PlainsTerrainSkin.draw_platform → _draw_surface → PlainsCohesionArt.draw_surface → clipped_strip_pieces。最后一步按世界相位重复带左右端帽的完整 WOOD 图。旧测试验证 PlainsTerrainSkin.surface_pieces 的 cap/middle 数组，实际链条不用该函数。已有正确文字规则没有落实到消费者证据；开发者又把局部通过概括成全项完成。失败不是手机缓存的推测，也不是用户现在才提出新要求。

## 修复规格与限制

保持 one_way_collision、定义矩形、生成算法、PlayerMotor、伤害与奖励不变。真实模块为每个单向面创建一个 PlainsWoodPlatformArt 画布对象，两端采样母图对应端头；仅无铜环的中段周期采样。周期接口用同源内段交叉渐变，使用预乘 alpha 避免透明 RGB 污染；局部坐标固定材质。复用已有 v6 原图和来源，不另造素材，不把此次采样修复称为新母版已获认可。

宽度小于60单位时等比缩小端头（不重叠），正式样本最短70；8/24宽是压力样本，其可读性并未得到玩家认可。长条中段仍存在可见重复节奏，是后续美术变体的待审事项。石灰岩、装饰、Boss和镜头没有在本次重新签品质通过。

## 可证伪验收

| 场景 | 方法 | 观察/失败条件 |
| --- | --- | --- |
| 两张正式地图的全部单向实例 | 启动实际 DemoApp，遍历模块节点和真实碰撞 | 每个实例唯一对应生产 shader；物理类型/矩形一致；漏一项即失败 |
| 极短/常规/长/非整格 | 同一正式 PlatformingModule 绘制 8/24/60/96/192/383.5/1000 宽 | GPU连续横向覆盖；内部透明断裂即失败；输出截图不冒称通关 |
| 固定语义改变尺寸和位置 | 比较真实像素端部、平移37单位后的图案 | 长度改变端头不变；平移无世界相位裁切；GPU8位舍入容差1/255，实际差异数量记录 |
| 覆盖规则反例 | 遗漏消费者、错场景、旧版本、helper代替画面、重复ID | 结构检查拒绝；不声称真实独立 Skill 调用 |
| 旧正式绘制负例 | 隔离运行旧整图循环绘制 | 相同像素性质应拒绝，保留截图与结果，不改正式游戏以制造失败 |

正式合屏通过移动审查镜头取得，玩家没有传送或完成路线；HUD的区域名仍跟随未移动的真实玩家。仅证明该版本正式场景的绘制，不证明玩家操作、设备性能。GPU Linux Mesa 与浏览器另列。完整记录及命令见 docs/evidence/one_way_platforms 和质量 JSON；仍待玩家对最终合屏的认可。
