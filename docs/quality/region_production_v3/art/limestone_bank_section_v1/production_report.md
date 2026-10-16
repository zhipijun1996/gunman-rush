# CLIFF-01：真实单图原件，完整420×152用途未准入

仅写隔离 `/workspace/gunman-v3-assets`；ROOT `/workspace/gunman-rush`仅提供只读原参考。作者 `/root/v3_art_director`；源base `41cab3ef503aa9aaae86ab74dc55afaaf21655bc`。实际implement nonce `8f327b2067404e85b115156f689248dc`、request_hash `36ff32fa99fc880b5df9f8ce998fc60295afd5450279c3d5d928035b57b70885`、source_hash `b5d453c210bb6df46510cdb14153425ab8235ed0c96e7c86213f49ffd5fb2a2a`。ROOT正式派发有效租约后完整读prompt/三个专业Skill；实际view_image原参考，再唯一image_gen.imagegen，56.151秒，保存完整原图并view_image(original)。无额外图生、引擎、代码绘画/抠图/重采样/alpha修改。

source.png 2048×768 RGBA，SHA `02e7832d5a4a9238af1ac307d4f4688c22ea7927cf88eb99f56a126a13d404db`，逐字节等于工具原输出。tool返回image_url/output_hint，真实原文件位置/精确prompt/refsSHA/便携原参考/耗时保留；model/license/cost均not_exposed。

## 原冻结包络的失败：不改阈值、不凑物理frame

alpha128主体bbox[35,93,1973,595]，比3.315966，等比宽420时高126.659909。目标是有站立带与完整侧底的420×152结构，不是只要任意宽石簇。

这不是简单拿alpha矩形比率作审美判定：即允许原冻结左右各外扩8，完整alpha128宽度最多436world，则整原件等比scale≤436/1973=0.220983。原件所有可见body最大总高度只有595×scale≤131.485world；而真实standing y0连续可见，152深处底内凹最多6，至少必须仍有146world可见厚度。131.485<146，必要条件不成立。根本无法靠选择一个新的standing/source frame同时满足原左右包络和厚度。不单独拉高、不后移边界、不裁掉更多端头宣称合格；physical_source_frame/standing_band_px/anchor_px/ground_line明确null，不编造接入锚点。

原母件画出了连续暖白/冷紫岩面、完整左右端/自然底缘、少量草根和上左光，素材本身不是坏格式。源图低宽大体量比放大石簇正确，但岩层底部有明显波动、左顶略抬，实际完整420×152近岸消费者未获准入。它不替代旧实体站立边、不用多张图叠根填洞、不冒充seamless。若未来以本原图测端/底/内部接口作不同重组消费者，需要独立任务和真实接缝/包络/GPU证明，不能追认本次整件通过。

## 实测与接口候选

alpha1 bbox[0,0,2044,768]，alpha2 bbox[32,87,1982,603]，alpha128外padding35/93/40/80。内部alpha128没有全高空竖列；opaque fraction约0.58539。这不是所有裂缝/边缘/GPU通过；alpha0处RGB渐变不能说成游戏中有底，source低alpha尾部也未经实际采样判定。

family.json记录必要条件失败及实际source完整图；接口只作可复现候选：完整左端region[0,0,370,768]、完整右端[1710,0,338,768]、底轮廓[0,500,2048,268]、内部材质[370,220,1340,300]。保留方向受光、不允许镜像/旋转；没有导出任何裁切PNG。没有按等分tile猜seamless；这些regions均未获可拼接/站立/物理匹配许可，不能直接推广。

近危险/唯一落点的min(3,净空/4)、standing连续带、侧凹单次高12、底内6/外10、头顶等冻结条款继续保留在原task_input/frozen_edge_envelope。由于整件必要条件已失败，不能为其他局部项造passed；完整站立/source frame与实际GPU/side/head反例仍未验。

## 范围与流程

实际Python PIL/numpy原字节/SHA/RGBA/alpha及必要条件测量exit0，证明来源与失败事实；`python3 tools/check_art.py` exit0仅验证既有全局manifest，不包含新未晋级母件。原Harness会另执行art-art并排独立review，本作者不签其检查结果。source/family已冻结，production_pool=false、full_consumer_admitted=false；共享manifest、ROOT、旧源/旧失败卡、游戏脚本/物理未改。

G0/design保留failed（原近岸用途），technical仅来源与真测量记录passed。G2真实游戏、全区、玩家/设备/性能均unverified。实际ready_for_review提交不同作者审查；本任务图生1/1到顶，不再出图。A失败只停止A，PANEL仍按原controller独立无依赖推进，待ROOT派发其新租约。
