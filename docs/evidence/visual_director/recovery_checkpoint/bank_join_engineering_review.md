# 岸墙接合新shader及实际观测：限定工程认可

审查者 `/root/visual_pipeline_engineer`；当前HEAD `a58d0dd7fe108698d7405ccbcbb6743cf94cd704` 加未提交修订，准确源码SHA见同名provenance。仅只读审阅本代理未实现的两shader、space材质/观测分支和实际测试记录；**本人编写的visual_director adapter不在独立通过范围**。未修改tracked、运行引擎/测试/ffmpeg，未查看游戏像素，不签商业美感、设备或完整视觉准入。

**结论：ACCEPT_SCOPED（新增岸墙着色与Control观测的技术方向/已核验有限证据）；完整黄金仍UNVERIFIED。** 没有发现当前冻结源中重复采样乘色、改变alpha/碰撞或默认跨全图调色的确凿阻塞bug。开始审阅时fixed电影仍running，最终写报告前重新读取已成为captured，才记录其终态；不把原有失败覆盖为成功。

## 实际修复与失败保留

原 `creek_static_v4_bank_join` 确实为failed：日志重复 `Invalid access ... global_transform ... ColorRect`，原receipt保存native process status=failed/exit0（有错误/完成契约失败，exit0不等于通过）。原AVI、完整日志、原receipt、raw、media-only诊断均保留；media-only明确native_admissible=false，没有救成技术通过。`source_preserved/index.json` 的33个源/资产文件逐一SHA重核均一致，其中旧space为`14d0013b...`，与失败receipt对应。

新space为`142603ac6ea748fb9479458bc3819503b517d8737adc75b613536b20cf418564`，两shader为`42994de8...`、`d215db88...`。ColorRect测量已使用真实CanvasItem方法 `get_global_transform()`，不再使用Node2D专属property。新强验实际观察非空bank rows、逐quad真实world bounds相等、显式 `_process` 采样非空；不是仅修改getter后不走实际分支。

`space_tests/run_rxsra829` 12个真实场景子进程，正例18/0、translated_parent21/0，其余真实坏Node/材质注入每例18断言1失败并exit1，精确命中root/scale/depth/clip/bankscope/disabled/ferrygraded等诊断。原运行日志与capture逐个SHA均吻合。704个原formal code/resource来源前后完全一致，当前space/两shader/runner SHA吻合；wrapper自身producerSHA另核吻合。该source范围包含实际shader和GD/资源JSON，**不含PNG字节或所有Python工具**；位图完整冻结要结合正式movie的扩展资产快照及wrapper自绑定，不能把704个SHA误说全仓文件。

## Shader语义核验

`plains_tile_material.gdshader` 新支由 `well_bank_enabled=false` 守卫。默认不进入RGB后处理；原采样、contour、`paint.a *= contour`、最终`COLOR=paint`原样保留。新增world varying不会决定碰撞。显式开启时只改`paint.rgb`，使用真实world区域限制，不写alpha；前28world高度的below_grass=0保留草缘。它仍基于原绘画，局部压缩采样/侧面冷影是表现变化，不能证明资产/空间更精美。

冻结参考shader字符串逐字节等于当前HEAD修改前shader，SHA `a37c91d8a51a04e29ff6f34aa26d9cc22b4ca5b068848c38d90810f8c338f4fd`，并非另写容易通过的旧替身。真实软件GPU probe为7断言0失败：旧与新默认像素字节相同；开启后全部alpha相同、前28world草缘相同，body9600像素确有变化；远壁alpha相同、1458像素改变。以上只覆盖一个192×160隔离fixture，不推广为所有复杂轮廓/设备证明。

远壁shader在**vertex**将COLOR保存为item_tint，在fragment独立采样一次 `texture(TEXTURE,UV)`，最后乘一次item_tint。因此没有把fragment阶段已含TEXTURE的COLOR再乘TEXTURE，也没有在当前代码里重复乘Modulate。生产Sprite的实际冷色调/透明度仍来自一次tint。隔离far probe的Sprite tint为白色，故该probe本身没有验证非白色父链modulate；上述单次相乘判断来自明确源码语义，不假称多种tint实际GPU覆盖。fracture只改RGB、不裁alpha或UV；特定源像素region是此资产的局部role-lighting，不能称通用自动构图。

## 实际选择范围、生命周期

新branch只扫描 `stage.terrain_art.art` 的实际ColorRect，先用get_global_transform测量其world rect与左右bank区域相交，再传完整world区域；fragment再次逐像素限域，quad只部分相交也不会整块调色。区域不进入真实开放船道。该art消费者的 `collect_solids()` 明确排除one_way_platform_indices，移动船为单独painted_art子树，不在所选art下；另有真实ferry_graded反例阻止错误启用船材质。每个tile quad原先由composer独立创建ShaderMaterial，未共享修改全部实例。

几何重建时TerrainStudy先free旧art再构建新art，space按实际art instance id变动清理旧Node引用数组并重新绑定；无新增持续保存材质服务。ShaderMaterial由quad持有，空间数组保存的是Node引用而非额外Resource持有；正常树销毁可释放。默认无诊断参数时不写观测文件，但仍有普通资产读取和每帧表现更新，不能称零I/O或零开销。新空间没有输入/碰撞/资源/相机控制权。

## 仍需明确的局限

- `bank_material_issues()` 对bank_quads遍历未逐个is_instance_valid检查；若未来TerrainStudy重建失败并令art为空，旧节点已free，显式诊断分支可能访问旧引用。普通无诊断运行会提前return；当前冻结Map2及实际12case未发生此情形。无需为当前录像中断改源，但后续处理重建失败时应清理旧refs并记录缺绑定。
- 已实际验证移动船与one-way的消费者隔离；未验证所有复杂倾斜/旋转父链、全部Seed的bank区域语义或局部染色在手机上的性能。`translated_parent`只证明其声明的实际父链平移案例。
- 范围与alpha正确不等于视觉接合自然。真实movie里阴影是否过重、远壁裂口是否仍像平台、绘画拼接与焦点是否改善，必须由独立像素/连续画面审查决定。
- 本审查最后观察fixed movie已captured且源前后相同；实际bank观测与原生结果见provenance。新终态不能追认旧SCRIPT ERROR，也不能为尚未看过的画面签G2。
