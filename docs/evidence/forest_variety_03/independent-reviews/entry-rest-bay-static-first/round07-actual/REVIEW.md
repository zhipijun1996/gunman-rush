# Round07 新入口独立审查

结论：**限定接受新休整入口的实际通行**；不签整图、难度曲线、趣味或美术。原 round07 总进程 exit=1，附林当轮仍失败，绝不将总批次改签为成功。

独立由 baseline `ee0b646e779b4680319e9a377518b27c10bfbe87` 与原 `changed-source.zip` 重建并核对全部 **3659** 条源路径：32 条 changed、3627 条 baseline，全部 SHA256 相符、运行前后 inventory 相同。没有启动引擎，没有改生产、Motor、几何、参数或原测试。

## 实际轨迹

正常旧 spawn `[-2200,1882]`，H-only；D/W 关闭，pulse_gun tier1，初始 HP5、shots2、energy100。492 个连续 tick 均各有 1 次 Motor step；原件声明无手动 Motor、midroute 注入或资源覆写，初末 tuning / traversal 配置 SHA 相同。

7 个 itinerary 段全部实际完成，每段末12帧复核原支持实体、完整24wu脚宽、真实地面与原目标判据（横向≤7、纵向≤2）；本审查另外逐帧用12×18半体积扩张全部危险矩形并扫相邻帧连续线段，0次交集。所有帧 HP5，无实际 shot_fired、无 committed player damage。

- 原 lesson 实际钩触 tick178。
- H1 tick285 从 `[-1804.986,1745.023]` 实际发钩，tick295 触旧 A，最终 tick360 稳定站到新湾 `[-2050,1790,165,40]`。该段137帧。
- H2 从湾中心实际沿枝走到右肩，tick400 在 `[-1900.019,1771.925]` 真实站地；tick403 跳、tick424 在 `[-1900.019,1685.023]` 实际发钩，tick439 触旧 B，tick492 在旧 innerbough 完整脚面稳定完成。该段132帧。右肩发跳的右脚边距约 **3.019wu**，不是悬空/半脚起跳。

右肩起跳实际避开原 innerbough 底部，修正了 round06 中从 x=-1980 起钩被旧底 y1604 截断的问题；没有搬旧目标、删旧体或改 hook 射线。普通 energy 维持100，**不据此声称 focus 免费**：实际瞄准 slow-focus 有消耗；该独立字段与普通 energy 不同。

## 限制与审查脚本修正

round06 的原 HH 和 root_spiral 实际通过对应 **140wu** 湾；此轮165wu不能直接继承其净空结论，仍须新源补验。首段添加休整不等于已证明对新手难度合适，尤其侧肩起跳有较窄足端余量。保留旧快捷/原设计，不能用此单条通过证明所有恢复/逆行。

审查者第一版附加了无依据的欧氏距离≤1判据，在首段提前停止；原日志原样保留 `../round07-reviewer-alignment-first.log`。随后读取并核对 **round07 清单对应的未改 baseline 测试源码**，改为其原到达规则横向≤7/纵向≤2（见 `destination-contract-from-round07.gd.txt`），完整脚宽和末12帧要求未放宽。此为纠正审查脚本，未改原产品/测试/收据。重跑完成日志在 `../round07-verification.log`；机器证据 `review.json`。
