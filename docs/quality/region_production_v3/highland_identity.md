# V3 风车高地独立构图候选

父任务 PLAINS-PRODUCTION-V3-01。采用 visual-director / art-director / scene-composer / region-generator；本包只改表现，不改生成、碰撞、资源、相机与 RNG。方向截止2026-10-15 22:45 UTC，最多一次新图与两次有因场景返工。用户/设备/商业品质未验。

实际查看 `shared_environment/static_final_frozen/windmill_repair_workshop_complete_v1_candidate.png` 1280×720、工坊和钟庭原始母版。已有工坊是低横屋顶+紧凑四翼，钟庭是低横残墙+大圆盘；高地需要不同的上升轮廓、通风负空间，而不是另一排屋舍。

备选A：三翼风塔+完整窄石脚，真实平台锚定，单图低成本。B：多风车远山脊，需要共享背景重排且易竞争已更新远山。C：风琴吊桥，会暗示不存在的通路。选择A。

## 图生前冻结 G0

- 一个完整透明侧视资产，浅石灰岩、旧黄铜、风化木、低饱和苔草、左上柔光，参考两件已有母版的材质笔触。
- 全轮廓等比显示宽240 world、高≤350 world；主体/翼片/石脚完整且四侧有透明余量，不裁基座。
- 底脚取原PNG实际不透明支撑包络，必须落进真实同高静态碰撞并集；不能跨物理缺口、借单向桥造根。
- 使用实际非教学 windmill_plateau，优先与已有后肩同支持并集的闲置左段；无 Seed 白名单，不新增随机调用。
- 深度0且风动0。不是功能平台、机关或互动钟。只在显式 `PLAINS_HIGHLAND_PILOT=1` 候选入口启用；默认准入交父级独审。
- 实机三观看窗口与多Seed完整Manifest前后不变，由父级排Godot窗口；静态pose不是通路/电影证明。

实际工具、提示、参考SHA、耗时与源见新族 `production/`。工具返回不自动成为G0/G2通过，失败原件保留。尚未生成/接入时不能宣称正式消费者完成。

## 实际结果与有因返工

唯一图像调用54.608秒，原1024×1536 RGBA、SHA `dae35a9981d6303f11216357a57ded6bb5282265c32834c90dc8fc6299dc4b2a`。完整三翼/石脚/开放支架成立，但alpha128主体858×1499，在原240world宽下高419.30，原G0高度失败，未改签。工具模型/许可/价格未暴露。

父协调明确允许不同的完整200world消费者候选。首轮实际GPU在三个正常地面镜头均暴露上翼出屏，故保留原件并做场景返工1：只将完整图等比缩到146world（主体高255.07world，足宽141.07），不裁切/重画/改变相机。正常zoom1.6的前两观看窗已完整显示翼与根；第三窗向右走时装饰部分移入HUD后，未遮挡玩家、落点或机关。细长旧功能立柱仍不自然，未因新塔掩盖此缺陷。

v1和v2均实际Godot4.7.2 GPU采集、exit0、Manifest完整字符串不变、798源清单before/after相等、actual_issues空。每轮约18.4秒；本包没有正常速度电影、触屏或设备性能证明。原生截图仅真实正式DemoApp中的reset pose，不能写成自动输入路线通过。

同一窗口另采旧两层树林on/off：同源、同actor、同camera、paused只切Sprite.visible且恢复。on有生命力但根坡横切与悬根明显；off消除这些缺陷但画面更空。该对为反事实诊断，不是版本改善证明，也没有单far层结论。

`PLAINS_HIGHLAND_PILOT=1` 下原directed-suite实际20maps，1135assert/0fail；原故意失败例210assert/1fail、exit1，source_stable=true。新塔实际11/20可建，9例真实左侧闲段不足明确omit；没有Seed重抽或弱化支撑。消费者只读Manifest/真实static union，不加碰撞/相机/RNG/资源权威。

源码冻结 `scripts/art/plains_semantic_landscape.gd` SHA `44f3a80b55341675f937190838092e49e353688f30551aa8a8bf3f524b354108`。不同代理实际像素审查、最终Web、完整电影/音轨/设备/用户认可仍未验，默认仍关闭，不自签生产池或商业完成。
