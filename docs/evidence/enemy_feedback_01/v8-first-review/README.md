# ENEMY-FEEDBACK-01 v8 first candidate · REWORK历史

本候选5ffd已独审REJECT：原活体↔新hurt存在实际色调／比例跳变，另外strict formal66/2失败。此目录保留原片／源码／失败，不代表后续修订已通过。

当前用户要求与拒绝原话见[user-feedback.json](user-feedback.json)。先完成原两个样板各自的hurt／death帧；**没有把所有普通怪物或完整运动状态批量做完**。V7新死亡爆裂声已撤回，两host回到原EnemyActor唯一default enemy_defeat提示；声音审美仍未完成。

实际生产运行源：`5ffd6e97a439d6397e4751b39206eebb622465dd`（生产同`8242c1a`，后续仅更正录制chain元数据与PNG chunk审计）。没有合main。帧／锚／恢复合同与总控保存接口请求见[规格](../../../enemy_feedback_01_frames.md)。

## 可直接观看

- [14秒当前Underworld样板](movies/after.mp4)：两种怪物，各含真实非致死命中、死亡动作和停留尸体。
- [20秒同条件v7／v8对照](movies/comparison.mp4)：每种依次旧消失／新帧倒地留尸。原音轨保留，未替换声轨或插帧。
- [14秒旧EnemyPresentation链样板](movies/legacy.mp4)：甲虫、叶片旋翼球壳保留各自美术，分别接同组件。
- [完整Underworld原片](movies/after-raw.mp4)与[完整Legacy原片](movies/legacy-raw.mp4)：各26.13秒，包含每种最后3.5秒连续留尸观察。

原生Godot4.7.2、1280×720、60fps、1×正常播放速度、原48kHz双声道；固定Seed=`enemy-feedback-01-remains`、镜头／输入／Definition／AI／武器／伤害／碰撞一致。显式定位fixture，不冒称自然路线或正式整区画面。MovieMaker离线录制速度不是设备性能指标。

两条链各6次真正HP提交、2次死亡，合计12次／4次；没有直接调用表现或health.damage冒充。两链的1560帧玩法投影及输入／事件严格相等，Underworld也与v7严格相等。每个实际消费者均观察到hurt0→1→2→3、death4→5→6→7，末尾210帧可见／静置／settled。见[movie-observations.json](movie-observations.json)及两个source-stable=true录制报告；原始JSON无损gzip保存。新增chain选项仅选原表现或原正式安装器，事件观察字段不改输入。

## 实现范围

4套原PNG、共32独立绘制姿态：Legacy甲虫／叶片旋翼机与Underworld獠牙甲兽／双翼铃虫。每套4hurt＋4death，低位末帧灭眼、收腿或折翼，保持尸体；不翻活图、不再爆裂消失。新atlas已有材料，关闭旧提色及lifeless压暗，保留accepted body flash、方向粒子和原HP／预告。

正式APPLIED／负增量／event_id／health epoch门禁不变，死亡与掉落仍由Actor／正式奖励服务幂等结算。两套继承链分别安装；Underworld父类死亡clock／可见性只读。舞台兄弟叶负责当前stage尸体与真实支撑，暂停不推进，卸载／epoch清理。死档直接D4，不重播闪色／动作／粒子／声音。

PNG原字节完整保存，region按实测分离沟槽取整数范围，不假称工具返回严格均格。PIL只用于alpha分析，无Python图像修改；PNG caBX实际存在但未独立验签，**Underworld两份逐字prompt未完整落盘，模型精确版本／许可字段未核实**。详见原素材目录的provenance／generation-result／alpha_region_audit／png_chunk_audit；不能以hash或元数据签艺术来源闭合。

## 验证与真实失败

Root专项最终native458/0、support199/0、默认death_audio278/0、GPU258/0。所有通过均保留实际来源、命令和原日志；独立精确源运行见[independent目录](independent/)与[review.md](review.md)，受影响原Harness单独列出。原Harness fresh actor-actions2872/0、underworld-damage-feedback317/0、underworld-formal96/0(两图)、forest-bible-integration54/0均通过；环境重启中断的第一次Harness没有完成标记，不计通过，原件另留。完整Integration仍未运行，不把Development计划升级为完成。

**默认正式App的strict formal66/2仍失败**：两处“official restored corpse stays visible despite hidden saved EnemyMotor”。存档没有保存实际落尸位置与support-local关系，当前仅能核实保存位置接触带；缺支持明确missing_saved_support，不能吸附任意远地面伪装恢复成功。旧v4的62/1移动渡船失败保留，当前不是旧62/1，也不能再用v5–v7消失合同豁免。总控Actor／Stage／保存schema只读，本线未另建保存系统，未放宽任何重载可见性断言。

探索期真实失败、原日志和截图见[root/precommit-failures.tar.gz](root/precommit-failures.tar.gz)与[failure-notes.md](root/failure-notes.md)：旧anchor原点当脚底造成native458/4；GPU244/2和258/2实为floor-ray=INF测量失败，不能称实像素间隙；另250/4含隔离层／空source观察器错误。修正测量后保留原380.01脚底阈值、原x精度、GPU间隙≤3px。正式66/2属于当前生产保存问题，未归为观察器错误。

新帧与旧live接续、色调／轮廓、尸体观感、音色及用户手感仍须实际评价；完整locomotion、正式forest／ActionStudio选择消费者合屏、非单位缩放／斜坡／旋转支撑、真机与完整Integration未验证。整体质量维持REJECT／draft；当前短片不是丝滑、整区、用户或设备认可。

## 可恢复源码与媒体

[runtime-source.bundle](runtime-source.bundle)包含真实拍摄5ffd运行源，前置公开提交`12d7e41abe62dfdfd33d5c15c1142b3ff84d14fd`；在已有前置提交的仓库执行`git bundle verify`后可fetch该bundle的HEAD。API发布提交元数据可能不同，以最终交付树和bundle实际运行源分别标识。

原始影片、无损trace、source guard、ffprobe与每段原始时间区间／封装命令分别在movies/{after-report,legacy-report,recipe,legacy-recipe}.json。两份14秒成片各840帧，对照20秒1200帧，全部60/1；只裁连续原帧及对应原音频并加事实footer。封装脚本在tools/，未用静图拼接、AI补帧、变速或后配音替代正式命中证据。
