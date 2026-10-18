---
name: visual-director
description: 统筹真实游戏像素驱动的空间美术生产，路由资产、构图和动画专业Skills，执行黄金实景、独立视觉审查及有界返工。
---

# visual-director

## 触发与边界

用户要求提升正式场景美术、建立美术生产能力，或反馈空间空、贴片感、缺景深/身份时自动使用。当前平原从[当前场所制作范例](../../../docs/evidence/plains_places/recipe.md)与 `PLAINS-PLACES-01` 进入完整场所实验，未准入；停止把失败的薄肩带接法派给下一轮。不接管art-director的风格与资产责任、scene-composer的空间实现、animation-vfx的动态制作；本Skill负责从实机证据定位责任、组织顺序和决定下一次实际返工。复用[原生产循环](../../../docs/quality/production_loop.md)、原G0–G5/十一维，不能用新总分代签美感。

## 输入与依赖

读[AGENTS](../../../AGENTS.md)、[当前状态](../../../docs/current_state.md)、[Visual Bible](../../../docs/visual_bible.md)、真实运行消费者、资产生产记录及失败像素。先fetch并保存完整SHA/工作区状态。输入Seed/Manifest、合法能力、真实镜头/路线与分辨率、用户视觉方向、实际素材和工具能力、原图/实景/连续录像；缺项保留未验。用户认可过局部材质不等于任何新空间用途获准。核心Motor/武器能力/资源/RNG/save保持；普通覆材冻结已验布局。显式授权的局部几何/平台/镜头联合实验依[共同契约](../../../docs/creative_direction/README.md)重新设计与真实操作验证，不沿用旧物理通过。

## 阶段流程与交付物

1. 采集：用`python3 tools/visual_director.py capture --help`对应的真实命令，复用正式DemoApp/PlayerMotor/输入、敌人与机关。固定Seed/路线/能力/相位/源；全片write-movie期间不做PNG读屏，结束后提取视频帧，记录frame/time，不能假称精确物理tick。
2. 诊断：实际打开正常尺寸游戏像素及镜头连续抽帧，分别标记资产质量、用途语义、宏观构图、光深/动态、可读性和采证工具缺口。每项给scene/Seed/镜头时间/像素位置、原件引用、事实或AI判断及责任Skill；没有实际观察不得签视觉通过。
3. 设计：从整体轮廓、负空间、主焦点、观看顺序与真实通道起步。中景大结构可以跨模块，根/连接/植生来源可信。分配极远/远/中/玩法/近/气氛职责与冷暖/明暗/清晰度，不以layer数量证明景深。
4. 资产：art-director先一件正确空间用途母版，实际看图/合屏再编辑同族。缺大墙就做大墙，不放大小石簇。记录真实工具/参考/版本/原PNG/派生/锚点/采样/来源/许可；未知不伪补。AI负责图像内容，代码只做已声明切片组织/Shader/接入。
5. 静态黄金：scene-composer在正式区域、本任务正常游戏镜头与完整玩家/HUD/敌人/落点下接入；先三个观看窗口成立，再补animation-vfx的统一风场/局部光雾。不能先用粒子/辉光掩盖失败大形。
6. 审查返工：不同实际代理看原分辨率像素和运动序列，输出明确REJECT/UNVERIFIED/范围接受、实际看图清单和未观看范围。按资产/构图/动画/可读性归责；一轮只围绕实际缺陷改变必要内容，保存原失败。两轮连续没有实质画面进步、关键工具不可用或预算到达，停止对应依赖。
7. 泛化：同一母版及其依赖须先有黄金静态/动态内部准入，才扩产；失败只阻塞该母版和依赖，不阻塞独立合格家族。给第二空间简短目标及其真实空间/能力/同族母版；不得把第一场景坐标、轮廓或逐点摆位当通用规则。技术验证可缩小，但不能冒称全区精修。
8. 交付：同条件前后实际截图/正常速度电影、客观变化和主观判断、真实时长/调用计数/未暴露成本、质量记录与独审；大任务结束部署最新Web试玩，给HTTPS/准确build_id/source SHA，不需合并main，不自动签品质完成。

## 设计要求

单个重要镜头先回答“什么空间、看哪里、去哪里、什么有危险”。玩法层最清晰，景物退让角色/弹道/落点/预告，近景不得依靠低透明度遮唯一通路。建筑有基础，岩壁有连续体量与断面，藤叶有挂点。大地图纵横移动、回望、镜像、长平台、深井均查实际覆盖和接缝；有意留白不自动算缺素材。严禁完整AI概念整图冒充正式合屏。

## 自动验收

复用`tools/visual_director.py`的实际`--help`与原Harness已注册专项。capture检查原命令/源不变/真实driver与systems/完整原生终态/媒体与帧引用；inspect的bounds、根/遮挡、缺深度是候选，不能输出商业美感PASS。compare要求同能力、路线/相位/driver/core与明确各自版本，保留策略失败和不可比较项。每个新检查有有效正例与错误来源/空记录/概念图冒实机/错帧/错误锚点等反例。快查只跑受影响项；交付执行完整适用profile，不改旧断言。

## 人工审查

真实不同作者的审查必须带实际看图/连续片段来源与定位；没有完整播放/音轨/实体设备就写未验。AI专业判断不升级用户认可。实际像素与runtime层数据互证，但hash、层数、文件名、alpha包围盒、测试全绿都不能单独证明好看或层深成立。

## 准入退出与返工

原G0–G5决定设计、真实集成、表现、回归及最终认可。全景/贴片已换不等于场景完成；阶段接受必须写scope，所有适用主观/设备未知保留review。先黄金后泛化按资产家族与真实用途执行；原冻结合同失败保留，不得改阈值追认。确有不同用途的技术试点另列入口、消费者和实际像素审查，不升级原母版准入。此内部生产顺序不因缺最终用户签字而反复问普通技术许可。重大新风格/核心玩法变化仍只提候选。每轮真实保存生成/编辑、实现、采集、审查与验证耗时，缺模型价格/用量接口写not_exposed。

## 完成与证据

可见采集必须先验证输入传输：固定物理步长与慢速录制不是同一时钟。当前正式采集器在上一画面实际post-draw后才生成下一条新输入，保留Router原100ms TTL；禁止重盖旧请求时间戳或延长TTL。用真实超过TTL的延迟反例验证仍拒绝；观察边界年龄不是Controller消费回执。见[实际时序反例与独审](../../../docs/evidence/region_production_v3/capture_input_timing/independent/review.final.md)。旧失败没有时间戳时，不得追认其根因已经证实。

跨版本对照保留原compare拒绝：相同Seed/逐tick位置相同，也不覆盖Manifest或实际driver来源差异。可以另报实际字段差异与相近镜头，但不得删字段把全内容升级包装成纯美术实验。仅同版本表现修复才沿用严格同条件比较。

V3实战检查点：开始昂贵worker前，原production_loop会物化核对所选检查、完整Harness入口和tracked证据依赖；缺件/外链/读取权限未知应calls0 blocked，不能让worker猜测试脚本名。按host_request内真实argv执行，`quality-tests`不是名字相似的补充Godot runner。见[实际预检及权限反例](../../../docs/evidence/region_production_v3/check_preflight/README.md)。

共享远景也要有渲染预算。两张全屏五采样画面可能比一张贵很多；先记录实际同镜头样本，再减少无效采样，不能先改输入TTL/角色规则。V3实际三窗ABBA与真实像素复验见[sky性能专项](../../../docs/evidence/region_production_v3/sky_sample_optimization/README.md)及[不同代理复核](../../../docs/evidence/region_production_v3/shared_environment_parent_review/sky_optimization_addendum.md)。软件静态计时不外推真机FPS，去微小模糊也不能宣称像素完全相同。静态pose/相机扰动、正常输入路线、电影frame与物理tick分别记证据。

断线后先判断哪些实际进程/代理仍存在，不能把有效但未被消费的审查响应补写成旧loop已完成；原PID无法证明时保留孤儿状态，由父任务用新独立审查和原字节整合，明确不冒称旧租约恢复。已生成且可验证的源不重抽，失败不退款。新导出检查读取真实PCK目录与每个导入后端映射/字节；preload纹理不强求无消费者的raw PNG或family JSON，但FileAccess读取者必须验证原始载体确实入包。实际Web构建/浏览器仍需另验。

共用`docs/quality/records/<task_id>.json`。输出有真实消费者的设计卡/资产家族、source-bound capture、独立像素缺陷与返工包、前后对照、时间账本、复用范围和部署版本。自动化必须是原production_loop真实租约/真实专业worker/实际检查/不同代理审查，不是预填host_response。示例：“溪谷井庭缺围合”先实景审计→承壁母版→同族后壁→正式摆渡/返程镜头→独审修复，再验证开阔钟庭；不把同一拱门复制到两处当泛化。

## PR69后的真实产出与验证成本

用原production_timing记录生成、实施、集成、独审、返工、验证、等待和发布实际区间，未知token/价格写not_exposed；宿主包络不称纯模型compute。廉价接口先于昂贵回归；只复用source/argv/consumer/artifact一致回执。恢复核真实lease/checkpoint/controller，发布绑定repo/ref/SHA/run/attempt及公开PCK指纹；保留原红，不另dispatch掩盖。

## 当前候选首整屏先于扩产

简短平原任务核route的 `preparation.visual_recipe` 是否指向[当前场所制作范例](../../../docs/evidence/plains_places/recipe.md)和 `PLAINS-PLACES-01`；若仍推荐旧thin shoulder/端alpha，纠正当期任务方法，不能让旧路由覆盖真实失败。顺序是整块PNG共画顶肩侧底 → 实测源图语义轮廓、站面及等比锚点 → 联合设计三个局部place原型 → 首样板实机/独审准入后验证第二场所和Seed结构重排 → 用全局camera协调跨场所景深。预列三个原型不是放行扩产。实际路径为 `plains_place_plan.gd` / `places_v1.json` 与 `plains_place_composer.gd`，当前均为隔离候选，不是正式生成器升级完成。独审要看完整屏幕、连续穿越/回望及对象动作；局部图、相位Seed差异、工程绿灯或旧B/P1接受不能证明这条方法成功。

## 共同创作契约

[预制作→制作→验收及版本总谱](../../../docs/creative_direction/README.md)是共同执行依据。总谱SHA变更须RETHINK并复验；交付写贡献、协作、新行为/视觉、主题冲突和实机验证。REWORK局部修复，DISCARD隔离候选；ACCEPT只限真实已验范围，审美不绕过工程红灯。

历史复现按需读取[原始Skill与迁移索引](../../../docs/archive/skill_history/README.md)，不默认加载旧轮授权、PR实录或失败数字。
