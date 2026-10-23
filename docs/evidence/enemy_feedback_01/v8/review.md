# v8 修订后独立审查：REJECT

**整体仍 REJECT。** 正式重载后尸体可见性仍有1项失败；新帧回接有所改善，但未全部关闭轮廓跳变。真实关节帧、当前房间死亡/落地/尸体保留可以局部评审，不签艺术、用户、设备或可合 main。遵循 gameplay-reviewer/review_method、animation-vfx、game-quality-gate；未改生产或 tracked tests。

## 独立运行与源

独立树 `/workspace/enemy-feedback-01-v4-after` clean detach 到 `3003bd0f10ed9c7fe51e0cdc5952aa579a87f130`。输出全新 `build/enemy_feedback_01/v8-final-independent/`；source-before/after 的1905个 tracked scripts/tests/tools/任务资产 SHA 全等，结束 git status 为空，不冒称根树文档冻结。

| 独立检查 | checks/failures | exit |
|---|---:|---:|
| import | 完成 | 0 |
| native 实弹 | 458/0 | 0 |
| formal/default DemoApp | **66/1** | **1** |
| support/void/恢复顺序 | 199/0 | 0 |
| 原死亡音频，正常时钟 max-fps60 | 278/0 | 0 |
| GPU pixels | 258/0 | 0 |

完整退出状态、命令、耗时及错误在 execution.json。除 formal 的 `official restored corpse stays visible despite hidden saved EnemyMotor` 外，无专项 SCRIPT ERROR、运行错误或退出泄漏；GPU 仅既有 VSync 警告。相比首候选66/2减少一次失败，不能写成正式恢复通过。保存数据仍不含真实尸体落点/support-local pose，接口未分配，不能猜测远处落点补齐需求。

原四项 Harness 本源全部 fresh/reused=false、exit0：actor-actions2872/0、underworld-damage-feedback317/0、underworld-formal96/0（2 maps）、forest-bible integration54/0；报告 `build/verification/harness/20261023T014356.200079Z/report.json`。内层13条森林 ERROR 是显式 EXPECTED REFUSAL 畸形存档负例，保留原日志。首候选5ffd的66/2、视觉 REWORK、环境重启中断及其后来独立重跑均保留在 v8-first-review/旧独立目录，本次结果不追认旧失败为通过。

## 源码结论与实际媒体

两 host 分别安装新 Frames，非致死 hurt 来自既有 APPLIED 样本，致死仅接受匹配 epoch/event_id/serial 的一次事件。stage sibling 接手D1–D4；死档直接D4、首次 physics 静态校准，不重播。弱 support、卸载/installer释放、暂停/新epoch清理均受本次测试覆盖。父类计时/可见性、Actor/AI/碰撞/伤害/奖励/保存schema未改；v7 helper配置已撤下，音频专项检查实际 pooled voice 为原默认流及唯一原cue。

修订按相同alpha>16可见范围作整套固定Vec2缩放；Underworld新增材料分支保留原live路径，Atlas局部UV逐帧更新、回原图重置，Legacy仍保源色。真实Motor中心确认已跨越的地面、逐帧alpha脚底扫掠和保存碰撞脚±2查询有源码依据；不靠放宽 formal 断言通过。非单位世界缩放、斜坡/旋转支撑仍未验，不签通用变换/地形支持。

实际查看最终两原片 `build/enemy_feedback_01/v8/{movie,movie-legacy}/after.mp4`，**每链240个解码帧**：MP4零基54–114、178–229、834–894、962–1025逐个邻帧，另看775/1555完整尾帧。四图有足/头/翅与躯体的相对变形，D1–D4倒下/收拢及落地后保留，不是整图翻转。观察图和两片SHA、裁剪/帧索引在独立目录 `media/inspection-manifest.json`，观察driver原件也保留。两片source_stable=true、源3003；trace每物种各210尾帧可见/settled/静止。尾段稳定性据trace，未假称完整播放或听取全片。

**有限关闭旧色材反例，连续性仅部分改善。** 同样93→94和876→877回接，Underworld原先暗金→亮绿、暗铜→青翼的强烈色材切换已明显减轻，新帧回到同一绿甲/青铜族；死亡尾图实际贴地，未见旧版明显浮尸。但原图与新图的头、翼、身体轮廓仍可辨切换；Legacy diver876→877的腹部宽度/外形变化尤其明显，不能以整体bbox/luma接近签“丝滑接回”。局部 continuity 保留 REWORK；普通移动/完整运动帧尚未制作，整体艺术和HK手感不签。

## 未完成项

PNG原字节与首候选相同；四图caBX存在已独立逐块核实，先前PIL.info为空的推断已纠正。未验C2PA签名，不由metadata推断许可，也不填补Underworld verbatim prompt缺口。旧失败不删除。完整146项 Integration、自然路线、真人正常速度体验、声音听感和设备均 UNVERIFIED。

引擎/CPU/render租约已归还。本报告完成后停止写入。
