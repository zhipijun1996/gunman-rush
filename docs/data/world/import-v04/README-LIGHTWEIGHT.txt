世界灰盒 v04｜轻量传输版本

用途
降低附件上传体积。设计版本仍为 v04；所有设计规则、世界数据、逐房合同、布局、源输入、模拟记录、脚本、字体与许可证均保留原始字节。

省略内容
本包省略可再生成的 20 张 PNG、3 张 SVG 和 1 份 PDF 图册。原文档中的对应阅读链接在重建前没有实体文件，这是本版本的已知交付差异。文字规则、JSON 数据和数据检查不依赖这些预览。

清单
MANIFEST.json 核对本轻量包实际包含的文件；MANIFEST.full-original.json 是原完整包清单，仅供追溯，不能将其省略预览条目当作本包缺失错误。新清单的 omitted_views 列明省略文件及原摘要。
原 handoff-status 和 qa 数据是原包保留的静态验证结果，本次重新打包没有执行 Godot 实机验收。

重建预览
需要查看图片或 PDF 时，按 BUILD_AND_VERIFY.txt 安装绘图依赖，在本目录依次运行：
python render_development_maps_v04.py
python build_atlas_v07.py
字体已包含，无须从原包取回。需要发布完整新快照时，再按原流程运行 package_handoff.py。

任务范围
当前工作的范围由用户本轮任务决定。执行 MV-MIGRATION-01 时，原 CODEX_START_PROMPT.txt 所描述的世界灰盒施工仍属于后续任务。
