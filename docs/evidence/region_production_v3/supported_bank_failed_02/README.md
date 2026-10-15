# 第二次bank素材方向：实际失败并停止

本次真实调用image_gen.imagegen一次（53.8秒，主任务第14调用，本bank方向第2次源制作），没有接入游戏，没有运行Godot，没有改runtime三源，没有第15次调用。**不是画质修复交付，不是黄金场景通过。**

先从真实正式baseline/map2 Manifest和实际.tres读取所有solids，发现bbox420×152对应的真实截面是240×152 +160×144 +20×32薄悬挑。旧规格只提8world底部台阶，没有表达最后20world薄悬挑；因此不能靠bbox匹配宣称旧完整母版可用。第二个真实/08地图没有这个完整420×152形状。逐part与源码SHA见candidate_family/production/*inventory.json。

另冻新supported-overhang用途，不改变原420全厚母版失败：原始参考+准确技术guide+实际正式游戏PNG一次编辑。请求的2048×1024只是prompt，工具接口没有尺寸参数；实际返回2048×768。PNG原始alpha128主体1941×623，最大436/1941 uniform下厚度139.9423world仍小于既定必要146，冻结sourceframe也超出实际画布。站线首10world可见率仅32.91%，不是连续站线。实际看图还发现右悬挑过长、抬高顶面及主厚体提早结束。

实际失败raw图在candidate_family/source.png；request.json、tool_return.json与原始工具输出路径/SHA、raw_measurement.json、冻结用途、实际guide全部保留。没有剪旧图、alpha补洞、拉伸、改阈值、移锚点救图或第二次生成。工具/模型/许可未知项如实not_exposed。

原sampler/runner/py SHA与当前HEAD字节相同见final_status.json。失败源production_pool=false，无preload或正式消费者；Root另负责三个export preset精确隔离此目录。source.png.import若非实际引擎生成则不捏造，本包final_status列实际文件清单。独审、设备和玩家验收unverified。

原完整420母版旧失败契约分别以original_failed_family.json和original_frozen_edge_envelope.md保留副本；未改原件。图生工具仍适合风格概念，但本次实证不能可靠遵循精确碰撞轮廓；下一步需要先验证工具能否按分接口资产/近景边界工作，而非继续无界抽整墙。
