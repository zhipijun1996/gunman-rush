# V3-ASSET-01：两件原画生产事实，待独立preflight

作者 `/root/v3_art_director`；原Harness implement request `d7ef3de58b078c892182aa315fba2df349955ad48b1b9e905e57aad2962f4fef`，source_hash `e540932f8299bb9912f1fd6a9b7eed39222271b688162fa7bbb34782c7316c70`。原图参考先以view_image(original)实际查看，再真实调用image_gen.imagegen两次；无失败调用，无追加调用，无代码重绘/去背景/改alpha/重采样。调用1为52.329s，调用2为56.579s；真实工具仅暴露image_url与output_hint，model/license/cost均not_exposed。

## 原件和规格偏差

1. `assets/region_production_v3/spaces/bank_shoulder_wide_v1/source.png`，1862×845 RGBA，原图SHA482d7efebc589ed1d3a84803c4191c18e822ead44e55b21aa2b6d64fde534812。alpha≥128 bbox(xywh)=[23,50,1819,765]，主体宽高2.378，**未达到原≥2.8及约3.2目标**，返回画布也不同；620world等比高度260.747664，不能压成原190。原始规格未修改。现仅后崖肩/陆侧大岩坡候选，`near_bank_not_admitted=true`；完整横向斜体量已经产生，不能称近岸接合完成。作者实际看原图：暖白/冷紫岩面与v8接近，但苔草较亮，中央多个面有水平肩线；只适合清楚后退的独立岩坡，不能给不存在落点。raw预览有细红黄边候选；红RGB像素alpha≥1为3639、≥2为396、≥128仅24。未GPU实景，不能把alpha0隐藏RGB说成已经证实游戏光边。
2. `assets/region_production_v3/spaces/windmill_repair_workshop_complete_v1/source.png`，1536×1024 RGBA，原图SHA1f2a582ce195b80e19627a370ec25f514edc08f461f56a8a52816f1444afcd56。alpha≥128 bbox=[40,16,1484,969]，比例1.531，**比原约1.8更高**；500world等比高度326.48248。建筑已有横向低屋身、偏左风车和完整石基，比裁旧塔更符合维修空间，但转子仍偏大/亮、暖顶可能抢焦点，必须实景看。可见吊钩是装饰，不赋予交互/危险；源内翼是烘焙整体，尚无独立动画翼，不能旋转整栋房子。

建筑基脚alpha≥128在源y900..985的保守水平包络[145,1521]，含真实石脚/植生toe。整体宽500时foundation463.61186，超过已量camp400支撑的可用368；整体宽≤396.883721才满足368、≤388.255814才满足360。场景工程已实际打开两图，决定首trial380world（基础352.345world），保留完整地基/等比；其真实接合/清晰度仍需正式合屏，不由包围盒代签。也可以选更宽真实静态支撑或独立可信远基础，禁止裁脚或让房子在单向桥凭空长根。

## 实际测量与消费边界

每族family.json记录alpha1/2/128/250、padding、源锚/ground_line、实际canonical size、用途、明暗/光向、镜像禁令和独立准入状态；production/含精确request、reference_bindings、工具返回可见metadata、alpha测量。两图内部alpha128均无完全空的竖列；这只是空缝探针，不证明所有细部、采样边缘或GPU良好。建筑alpha最大254是实际返回，未人为归一化。

已建立spaces/manifest.json供scene适配，`production_pool=false`，depth0、禁止镜像/旋转。PNG/family/manifest现已冻结，指纹见source_integrity_check.json；后续真错误须新revision通知，不在渲染期间暗改。此时正式消费者尚未接入；拟由PlainsSemanticLandscape→PlainsRegionComposition消费。不同家族独立pilot，旧溪谷失败不阻塞建筑。

本作者检查原件与工具文件逐字节相同、SHA/尺寸/alpha/portable references真实。独立执行`python3 tools/check_art.py` exit0，日志在证据目录；它主要验证既有全局manifest，**不自动覆盖本轮未晋级的新候选**。自制source_integrity_check仅验证原件完整性，不评商业美感，不当作原Harness整套通过。

## 便携证据与未验

`docs/evidence/region_production_v3/art/`保存原implement请求、两call真实时间、五份原字节参考图、reference_portability映射、source_integrity_check及既有manifest静态检查。`docs/quality/region_production_v3/art/`保留原审计、原候选prompt/参考SHA与看图清单；原始绝对工具输入保留，便携路径另列，不能篡改为当时使用的相对路径。PNG是原工具输出，JSON不重复巨大inline data URI；原图及output_hint足以追原件，不冒称持有工具未暴露的model/用量/license。

G0资产生产证据已提交独立preflight；作者不自签通过。原形体比例目标失败明确保留。G1/G2/G3/G4/G5、正式合屏、完整动作/音轨、随机Seed兼容、性能/实体设备/用户审美均未通过此任务获得认可。没有图生成功=近岸合格、没有素材可用=全区升级完成的声明。下一步由不同作者审查原图/用途/来源，然后独立场景试片。
