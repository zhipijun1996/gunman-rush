# 当前交接：D068 平原实体辨识与较慢移动

分支feature/plains-branch-challenges；起点8700300，运行提交3eaa86d，继续[PR36](https://github.com/zhipijun1996/gunman-rush/pull/36)，不合并。本轮规格与A100–A102见[实体辨识与移动舒适度](../plains_readability_and_control.md)；上轮源图融合与公开包证据已[归档](handoff_plains_v3.md)。美术仍基于PR38/17edc86，不用旧美术分支代码覆盖玩法。

## 已实现

普通移动300→260，触屏两档143/260px/s，快速起停保持；首跳不变，未来二跳速度倍率1.1→0.9。平原仍一跳两射，二跳只在显式测试/后续能力配置开放。真实首跳150.366px、二跳新增126.544px（总276.910）。不是空洞骑士官方数值复刻，慢时0.20、反冲1100×0.14及相机不变。

正式反冲升阶260→190px、接收台210→260px；修改恢复桥和高级宽峡等几何与能力门槛，保留反冲需求。旧练习塔每层220/共660，长峡净空400。各模块提高definition_version；正式生成器plains-run-v6-grounded-comfort。降低速度后测试落点可能偏向接收台近侧，测试通过真实Motor落地后步行至原目标，保留身体扫掠、无伤及出口站立断言，不传送或删除负例。

近景装饰恢复原色，远景雾化保留。木板=单向可从下穿，石灰岩=实体（含薄实体台与移动台），视觉从one_way元数据派生，未偷改平台碰撞。荆棘自然比例重叠裁边，伤害矩形不扩大。新增原创石灰岩/木门/黄铜风铃/常春藤门，透明PNG和来源hash在runtime_integration.json；原20张源图不变。

厚岩地形向关卡底部接地，有真实碰撞；保守裁剪保护深坑、下层模块完整空间与所有机关包络。ground_support_version/精确矩形进入manifest，篡改/缺版本拒绝；薄台继续悬空，无法安全接地的岩块暂保留，不声称全地形已接地。

## 验证与证据范围

Godot4.7.2.stable.official.ed1daf0bf，统一tools/godot.sh，所有长任务有timeout。核心最终5894/0退出0；独立反冲余量114条真实轨迹/1490断言、模块库1096、恢复桥93、弱能力429、跳跃链7、蓝图5506、空间2489、正式生成4541均0失败/退出0。支撑专项308/0，12房间实际107地柱含物理查询；负例探针退出1。上述子集不与完整专项重复累计。

初始220/200高差余量不足、降速后旧能力门槛及接收台中心断言失败、地基旧子节点数量断言失败均保留日志；按实际落点修改几何/测试输入路径后重验，没有把失败记录标成成功。源图/旧资产/文档33权威94依赖/世界16区检查通过。首轮完整专项在金币支路往返测试123/2失败：2829.84px返程在260速度下原600帧预算不足，导致后续从错误位置起跳。按距离/速度计算有界684帧后固定步与实时时钟均123/0，非法fixture退出1；不是关卡无法通行。修复后完整28专项37740/0退出0（full-plains-final.log），无脚本/解析错误。

本地Web包8b751ba37161，24944760字节；实际Chromium移动触屏模拟7项通过、退出0：Title/Home购买5音符、刷新保留4音符/升级、正式1/8、实际三指独立松手消耗空中射击、普通移动及短跳，无Script/Shader/Page错误。此次移动只捡到金币，未实际新增音符，因此“新赚音符刷新”明确未重验，不冒充上轮9项。保留HTTP404。真机Android/iPhone、Windows实际手感/性能、最终美术认可仍待用户验收。

日志：忽略目录build/verification/d068/（full-plains.log、web.log、browser.log、modules-browser.log、speed260-*、ground-supports/*），核心build/verification/movement-core-final.log。截图与GUI报告在floating-touch-browser及plains-v3-browser。另实际菜单选择安全台/竖井/锯轮/移动台/Boss五项截图检查通过，退出0；已查看正式房间及锯轮/移动台截图。模块截图不是完整操作通关。

## 下一步

3eaa86d的[CI38064450100](https://github.com/zhipijun1996/gunman-rush/actions/runs/38064450100)已success：core/28专项/Windows独立导出、Web导出与Pages均成功，Android skipped。公开[试玩1d76a1ca0509](https://zhipijun1996.github.io/gunman-rush/?v=1d76a1ca0509)实际HTML/build-info/PCK一致，24948200字节，SHA256 1d76a1ca0509509ba3bb44b887aff5e406de7e747d4610c49172d0fc575bbc60与CI日志一致。公开GUI未冒充重跑本地7+5项；手机试玩重点：143/260两档是否容易停稳、190px反冲台是否宽容、木/石可穿性和门/荆棘辨识。进一步关卡变体、折返与新能力仍单独立项，不声称当前趣味性已获认可。Android本轮未构建；Windows由本轮CI独立核实后记录，不以Web成功推断。

## 最新用户反馈：趣味性仍不足

用户在本轮收尾明确指出关卡仍不够有趣。D068只改善操控和辨识，不能视为趣味性验收通过。用户随后明确参考遗忘十字路口内容密度，多机关敌人，并认可风铃按顺序加。正在开发D069：先正式路线遭遇与机关，再做射击风铃样片；未验证前不得列为完成。设计与来源限制见[crossroads_density_reference](../crossroads_density_reference.md)。
