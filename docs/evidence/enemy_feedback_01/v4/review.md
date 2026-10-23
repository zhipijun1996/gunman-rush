# ENEMY-FEEDBACK-01 v4 独立审查

**总体 REJECT：正式 moving-support 精确恢复仍有62/1严格失败。** 本轮亮材料、明显翻背/侧倒及平地接触可以作为当前房间候选交用户；扩大粒子空间是可证实的事实，但不等于受击主观强度或《空洞骑士》式手感已达标。完整动作新帧、整体美术和用户认可没有代签。

## 来源与独立性

实现者 `/root`；独立审查者 `/root/feedback_review`。按 gameplay-reviewer 和 review_method 审源码、实际像素、正式消费者、时间/epoch/恢复/退出反例。审查者未修改生产或测试，只写本报告和自己的 build 输出，独占 engine 顺序执行后已归还租约。

生产源为 **`8f0fd51db3bfcc4a08dd352c1c5909aad4f4fcf9`**；独立测试运行源为 **`0d5b72cc3a01f37d78c8e9d300d36fbba39a458e`**，两者 production 相同，后者只新增GPU检查。运行工作树 `/workspace/enemy-feedback-01-v4-after`；846个生产脚本/任务测试/驱动路径运行前后SHA变化0，不称整个workspace始终冻结。作者后续提交 `6de2d50` 增加独立粒子空间测试，生产未变；该80项测试由作者执行，本审查者只核原件与PNG，不冒充自己重跑。

原独审输出：该工作树 `build/enemy-feedback-01/v4-review/`（source-before.json、source-and-log-audit.json、四logs/runtime、GPU原PNG和media）。精选归档见本目录 `independent-tests/`；完整解码图索引由归档者记录，实际观看范围以下单列，不把全部已解码文件当成已看。v3失败/修复链及旧62/1保留原版本，不移签。

用户本轮四点按会话转述为受击更大、活死可辨、参考HK手感、怪物太暗；原音效deferred不变。不是用户已认可任何新配色或动画。

## 源码边界与风险

选中对象仍是 plains_charger/plains_diver。原 `EnemyPresentation` 与 `UnderworldEnemy → PixelPlainsEnemy → WindchimeEnemyVisual` 各自接共享叶组件；原正式安装器替换旧Presentation。没有新增伤害/AI/碰撞/奖励/保存合同或改父类死亡clock/visible/modulate。既有APPLIED HP提交与Damageable.damaged的event/epoch/serial门未改，不能把接触动画当接受命中。

shader只改body.rgb，保留body.a；readable_material仅选中Underworld body实例显式开启，旧atlas不启新palette。四邻alpha用于内面材质选择，不生成外轮廓alpha。死体继续由stage sibling维护，原alpha轮廓support extrema保留，改变终态角度后仍按真实轮廓投影接地。无TTL、CollisionObject、Motor位移、奖励或新信号；初始化直接静态恢复、卸载dispose及WeakRef边界沿用。

粒子细屑为1wu线条，新增三条0.075秒 tapered contact核中央全宽最高2.4wu，不能称整个受击层都是1wu。8/12片、加速和扩展空间未消费玩法RNG。shader/lifeless状态不修改伤害接受条件。

非阻断残留 EF04-N1：settled后_process直接return，charger本次实测lifeless冻结于 **.99238018**，diver为1；restore显式设1。它是精确终值不一致，不是击退/重播问题。没有独立证据表明这约.008差异造成可见缺陷；当前不以此要求改冻结源，也不声称两路径材质逐字一致。

## 独立引擎检查与日志终态

Godot4.7.2 Standard，Linux、Dummy audio、fixedfps60；GPU为Xvfb1280×720、gl_compatibility、Mesa llvmpipe软件渲染，不是实体设备性能。

native/support/formal实际命令：`bash tools/godot.sh --headless --path . --audio-driver Dummy --fixed-fps 60 --script tests/enemy_feedback_01_{tests,support,formal}.gd`，分别运行而非文字计划。GPU为去掉headless并加`--rendering-method gl_compatibility --script tests/enemy_feedback_01_pixels.gd`，保存独立display/命令回执。

| 实际顺序 | checks / failures | 完整进程退出 |
|---|---|---|
| native | 378 / 0 | 0 |
| support | 133 / 0 | 0 |
| GPU | 112 / 0 | 0 |
| formal | **62 / 1** | **1** |

formal原断言仍为`official restored corpse stays visible despite hidden saved EnemyMotor`，没有删减换PASS。根因继续是移动支撑随动后的视觉local pose未进入原保存合同；需总控支持稳定support身份/local pose与完成恢复后的解析时序。本线不能靠改Actor保存位置或造悬空地板补洞。

额外独立执行原Harness：`python3 tools/harness.py --check actor-actions --check underworld-damage-feedback --check underworld-formal --check forest-bible-integration-tests --release --jobs 1`。4项均fresh passed、exit0、reused=false；整进程exit0，65.268秒。报告：`build/verification/harness/20261022T181537.445734Z/report.json`，源0d5、clean。

| Harness消费者 | 完整日志marker |
|---|---|
| actor-actions | 2872 assertions, 0 failures |
| underworld-damage-feedback | 317 checks, 0 failures |
| underworld-formal | 96 checks, 0 failures, 2 maps |
| forest-bible-integration-tests | 54 assertions, source_stable=true |

逐项实际读完终态marker/退出：四专项及四Harness日志未见SCRIPT ERROR、ERROR、ObjectDB/RID/资源泄漏诊断。GPU仅保留不支持调整VSync的驱动warning。原Harness通过不覆盖本任务新增的移动尸体保存断言；`--release`是该次执行参数，不代表完整Release或146项Integration已执行。Action Studio正式可视消费者、完整Integration仍未验，不合main。

## GPU事实与消融边界

本审查者运行的透明viewport palette消融：保持同一body/pose/HP，关闭/开启readable_material。charger opaque mean luma **.130→.351**，diver **.125→.383**；两者原/新sprite区域alpha_changed=0。审查者另从原PNG复算整个viewport alpha差异也为0，画面外像素alpha均0，确认透明viewport确实生效，未把不透明背景掩盖的alpha当证据。实际打开未缩放原/新palette裁片 `pixels/review-palette.png`，原PNG/计算见review-alpha-audit.json。

实际死体 mean saturation约 **.166/.179**，活体约 **.511/.507**；死体luma约.344/.379，并非靠透明消失区分。charger/diver及暂停的真实body-floor gap均 **0px**，暂停crop与transform一致。上述是同样本的亮度、饱和度、方向及贴地事实，不是审美分数。

独立GPU粒子visible消融保持真实accepted burst的age=.033333、HP/serial/flash不变，只切换这一叶的visible；本层实际贡献23/17px，半径9.518/8.153wu。只此检查不能证明相较v3扩大，因此补核作者的`extent/v3/report.json`、`extent/v4/report.json`及原on/off PNG：同字节driver SHA `d71710b0e92f9d6c473c6f519e85c2a57b81e426910fdc2c91b138eef4bc126b`，各80/0，真实Router命中、等价fresh fixture、相同contact/HP/serial/Canvas/ROI与实际age，不混称全局physics tick一致。

审查者独立重算8组PNG差异的changed pixels/半径，与报告吻合（contact字符串打印精度带来<.00007wu差异）。0.1秒时charger **6.305→13.673wu**、diver **6.811→14.283wu**，约2.1倍；.033333秒包含新contact核，分别1.846→9.518、2.408→8.153wu。复算为`extent-independent-png-check.json`。这是本任务层的实际可见空间扩大，不是整个命中亮团变强2.1倍，也不签HK手感。

## 实际影片观看与专业判断

新片原件 `/workspace/enemy-feedback-01-v4-after/build/enemy-feedback-01/remains-after-v4-serial/after.mp4`，实际SHA **`07e06e1bad39c3c8628bd4b0c522d3f00af0efcf76dc702a9dcab8d50ae5cb2d`**；report记录clean8f0生产/source_stable。旧片 `/workspace/enemy-feedback-01-v2-after/build/enemy-feedback-01/remains-before-v4/before.mp4`，实际SHA **`730d9f45bd2059d0538e02ddc6f5f5a932aa1d48c35a8ebece22c16d61dbc0ee`**。共用旧driver，画面底部仍写v3；归属以source/report为准，不能凭overlay错认生产版本。

独立读取两trace验证1560帧的frame/case/local_frame/paused/player_position/player_velocity/enemy_position/enemy_velocity/HP/state严格相等，inputs/shots相等；events仅去掉进程局部Actor前缀后相等，保留session/shot后缀与其余字段。见media/comparison.json，不宣称raw event_id逐字相同。

**实际观看的是MP4解码邻帧与整图，未完整正常速度播放、未听音轨。** v编号为0起始视频帧，与trace frame不混用：

- 新charger非致死v55–76逐帧（.917–1.267s），死亡v177–232逐帧（2.950–3.867s）。
- 新diver非致死v834–855逐帧（13.900–14.250s），死亡v961–1036逐帧（16.017–17.267s）。
- 新原尺寸1280×720整图v30、600、820、1504：两对象活体和长时死体。
- 新末段charger v574/604/634/664/694/724/754，diver v1354/1384/1414/1444/1474/1504/1534/1564；跨段准备帧v784没有作为charger末态接受依据。
- matched旧/新原像素同帧v60/63/184/193/600/843/1504，另存media/matched-before-after.png。不是静图拼成的动画。

| 用户关切 | 真实可见观察与判断 | 范围结论 |
|---|---|---|
| 太暗 | 草绿甲片与铜边、冷青翼面从原先暗色里分离出来；主面更清楚，轮廓alpha未扩张。 | 当前fixture读形改善明确，可交用户；不签正式地形合屏/整体美术认可。 |
| 活死可辨 | 地面对象翻背，飞行对象侧倒，低饱和静止尸体与有色活体区别明显；接触收束后保留，未见原悬空或再淡出。 | 有限AI专业判断可继续；air仍展开翼，未画收翼/断支撑新帧。 |
| 受击更大 | 实测细屑空间扩大；matched帧里的主导亮团仍是既有cyan接触效果，新短芒/细点贡献比换肤和翻背变化小。 | 空间扩大成立，整体主观强度是否足够待用户，不宣称所有命中特效已改造。 |
| HK手感 | 可见接受闪色、方向碎屑、失去支撑到静止的层次；没有据此改变原战斗时序或复制他作参数。 | **UNVERIFIED**。未完整正常速度操控/试听，单图旋转不等于手绘动作或完整打击手感。 |

## 最终边界

v4当前房间的alpha/真实接受因果/epoch/暂停/卸载/贴地和所运行消费者技术样本成立；亮材料和活死区分有实际改善。**总体仍REJECT，正式移动支撑恢复62/1继续阻断完成。** 146项完整Integration、Action Studio可视回归、自然路线/正式美术合屏、新运动图集、用户与设备认可仍缺证据。作者粒子extent的80/0不算本审查者的引擎重跑。原v3失败、音效deferred和未完成项均未追签。
