# 恢复资产与继续制作

## 从其他会话接续

1. 打开 `references/asset-library.json`，确认当前16区版本；需要回看风格时查看随技能保存的已认可五区画面。
2. 项目已有 `bundle-manifest.json` 时按其中 `asset_root` 读取素材；用户给出解压路径时直接核对。项目尚未接入时，先确认当前交付是否真的包含原生包，再恢复到工作目录；方法包不重复内置完整素材。仓库已展开同套素材，按[Cloud接续](cloud-portability.md)定位。核对版本，不将旧包当作已含752格的v2包。
3. 核对包中的 `study.json`、`assets/pixel/manifest.json`、v2的 `assets/terrain47/manifest.json` 和预览。使用 `python3 <本技能目录>/scripts/inspect_pack.py <解压后的包目录> --region echo_mines --hashes` 定向查看；`--complete --hashes` 检查全16区，`--json` 给出机器可读输出。背景表允许18条，按各区 `background` key读取实际选中版本。
4. 查看本技能内已认可总览、目标区原尺寸拼装和地形局部。只有文字时先恢复视觉锚点，避免靠一段“像素风”提示词重新猜风格。
5. 对照当前项目的正式区域与实际地形加载入口。将素材包适配到项目现有格式，保留过往基准版本。

技能内附PNG用于对应风格与比例对照；完整16区原生素材和组装输入归项目或另交付的原生包。确有ZIP时才用标准解压工具恢复，保留原包。完整生成源图与Godot工程按资产索引恢复；`sourceFile`用于溯源，不能据此假定原始生图已内置。跨会话不依赖旧聊天或旧临时目录。

按当前技能的实际来源访问资源。存在 `skill_root` 时使用该绝对目录；只有 `skill://` 资源时，通过同一技能包的资源接口取得随附文件或完整bundle，再解压。不要把 `skill://` 当成本地路径，也不要从旧会话猜测本次技能的安装位置。

## 制作与扩充入口

恢复素材不等于批准当前构图或获得跨房型能力。制作按[主流程](../SKILL.md)先完成一间实际房间的整体画面，再从成品按需提炼；区域套件仅作[可选复用实验](regional-kit-production.md)。单次绘制的引擎职责见[引擎前置2D](engine-first-2d.md)，来源与字段见[素材合同](asset-contract.md)。

正式场景以项目当前房间、定义与组合为输入，旧素材包格式只用于恢复／转换。先共同校准本房的真实地形、平台与建筑，按实际画面补齐缺件；修复共享缺陷不复制到每个房间。项目已集成的消费者与认可范围分别查当前交接，不从内置样例推定正式采用。

## 重建入口

以当前包内 `README.md` / `NATIVE-KIT.md`、`package.json` 和实际脚本为准。16区包使用以下入口：

| 操作 | 入口 | 依赖 |
| --- | --- | --- |
| 查看离线拼装 | 单独交付的 `world-art-v2-preview.html`；构建脚本默认输出 `world-art-preview.html` | 浏览器 |
| 重建v2道具/景深/背景 | `python3 bake-v2-assets.py` | 本轮两份源图包、锁定的v2-assets-map、Python/Pillow/NumPy/SciPy |
| 重烘焙v2内凹角 | `python3 autotile/bake_corners.py` | 新角源、已审查crop清单、Python/Pillow/NumPy |
| 重建16区752格 | `python3 build-autotiles.py` | 原生地形供体、60个内角、Python/Pillow/NumPy |
| 构建/验证47地形资源 | `python3 autotile/validate_godot.py` | 包内47 PNG/manifest及Godot；只创建相关最小测试项目 |
| 生成真实组装画面 | `node render-study.cjs --all` | 包声明的 Node 依赖 |
| 生成动态预览 | `node render-study.cjs --video` | 同上及 FFmpeg |
| 构建离线预览 | `node build-preview.cjs` | 包声明的 Node 依赖 |
| 重建 Godot 场景 | `python3 godot/build_scene.py` | 原生包与Godot包合并，Python 3 / Pillow |
| 编辑引擎样例 | 导入 `godot/project.godot` | 兼容的 Godot 版本 |

原生包可直接组装已有PNG；重跑烘焙需要相应源图。按各包实际目录和说明合并，不能假定跨版本归档有相同顶层；Godot独立包可自行导入。历史五区的 `bake-assets.cjs` 与v1 `bake-new-regions.cjs` 用于对应旧源，不要用它们覆盖v2清单。`configure-regions.py` 重建旧区域配置时需要五区输入；普通续作直接编辑现有房间/区域数据。运行生成器前核对输出路径，手工编辑保留版本副本。

## 将结果留给下一会话

保存新源图、原生资产、清单、区域配置、复现入口和对应预览；完整包的可恢复身份比临时路径更可靠。将新包的名称、保存身份、版本、哈希和验证范围写入资产索引。

记录用户具体认可了哪张画面、哪些区域或哪些变化。扩展16区的请求表示可以制作，不等于全部新扩展已经被视觉验收。保留五区认可基准，并将新候选逐步提升为相应区域的认可版本。

更新此技能时使用个人技能的正式保存流程，连同引用和脚本一起保存；检查后续会话能找到资产。无需每次扩充都改技能正文：新增房间写入房间数据，新增资产写入素材包与索引，共享规则变化才修订规则页。
