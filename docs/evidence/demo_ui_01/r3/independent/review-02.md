# DEMO-UI-01 R3 独立复审 02

**限定 ACCEPT，运行源 `8dc2f4e6a2c6f511c22004784cb71b5f3d0d7a96`。** 本结论覆盖 R3 正式资源规则、五件道具真实效果链、激光直接耗能防回归、实际 HUD 像素、D/H 资格边界与时间环锚点/已检查生命周期。没有发现新的必修问题。它不等于用户美术认可、实体设备验收、全任务完成或完整 Integration/Release 通过。

审查者 `/root/ui_audit`；R3 实现者 `/root`、`/root/menus`。审查者未写 R3 生产/测试，未执行 Godot 或亲自操作原生 GUI；实际读取源码、原始执行日志/回执并查看 Godot 像素。本文与 JSON 是经总控许可写入的报告。此前 review-01 与 energy-first、d079-first、energy-v2/v3/v4 失败保持原状，本结论只接纳修复后的新证据。

## 三项缺陷闭环

| 原发现 | 当前证据 | 复审 |
| --- | --- | --- |
| R3-I01：旧单跳飞行容量误报二跳 | 新专项明确授予真实 D，再设旧 flight cap=1 / used=0 边界，确认 can_air_jump=false；真实恢复后重新可用。ledger 两边界均 passed。 | 关闭，未修改实际跳跃规则。 |
| R3-I02：地面 H 用后误隐藏 | 真实地面 Motor 碰撞 fixture、真实 H 授予、已使用标记下，HUD 图标与 request_hook 的地面许可一致；专项 passed。 | 关闭，不把取消/暂停当资源恢复。 |
| R3-I03：增长计数断成三行 | 实际打开 frozen-ui/native/max-growth.png，4.25/13.5 完整一行；13.5 上限对应多行心形，头像/共鸣及右侧导航没有交叠。 | 关闭，本次原件为1280×720。 |

## 像素与实际片段

实际打开 `frozen-ui/native/formal-hud.png`、`touch-hud-844x390.png`、`max-growth.png` 和 `film/ring.png` 四张原图。头像与右侧心形、心下共鸣、离散弹药成立，无旧黑色大底板、无武器块，场景与角色动作保持可见。手机目标窗口原件的实际渲染 viewport 为693×390；本审查不把它扩写成完整844×390窗口或设备安全区验证。

实际解码 `film/after.mp4` 全时段 0.00–14.75秒，每0.25秒一个连续采样，形成内存联系表查看，没有写新视频/图片文件。可见标题进入游戏、生命损失与恢复、6.25–7秒附近人物周围的时间能量环、释放后环消失、暂停→设置→返回→地图打开/关闭。不是原速完整播放，未听音轨，不能据此签动画手感、音效同步或设备帧率。

独立核对 MP4 与 trace SHA256 均匹配 `film/report.json`；ffprobe 确认为1280×720、60fps、888帧、14.8秒。report 运行源为8dc2f4e，source_stable=true。trace 第412帧同源能量74.5、focus_active=true、ring_visible=true；原 ring.png 中环确实围绕当前人物而非 HUD 原点。释放射击后 trace 能量不因射击另扣，环消失；暂停/设置区间能量固定。ring 的绑定、真实比例、Motor Canvas 变换、取消/暂停/死亡/解绑断言均通过。

## 规则与回归证据

本轮五件 v2 道具的真实 BuildState 授予、精力消耗/地面恢复/再武装参数变动、撤销回归基础值均有新运行通过。普通与三级激光分别在0和60时间能量下真实进入并推进 beam，不额外扣时间能量，仍使用一发空中弹药。正式时间资源保持 AirFocus 与 actor_resources.stamina 的同一身份；枪/钩空中慢时按真实秒耗能，接地只恢复一次。历史旧资源仅显式 fixture 注入，原数值断言与原字节档案保留。

核对 `harness/20261023T022139.746804Z/report.json`：6/6专项通过且非复用，source commit=8dc2f4e，release=false。新时间资源专项140项0失败，退出日志没有 ERROR/泄漏；frozen-ui/report.json 6/6通过、source_stable=true，包含原UI、标题字体、旧能量迁移、地区生命周期、Underworld UI、cloud preview入口。原生日志只见图形驱动不支持切换 VSync 的提示，没有据此隐去错误。此为已有真实执行证据的独立审阅，不能写成独审者另跑一遍。

## 未验与交付边界

公开浏览器尚待部署；Web build `5e9adddb1662`、PCK 146861240 bytes / SHA256 `5e9adddb1662e91690fb3d398534dc71e559e04e5bb3f21b1753ecfd20b9a3e0` 是总控提供的 staging 信息，本审查未独立下载/执行 Web。实体手机/手柄、用户美术与体验认可、自然战斗完整路线、音轨、完整窗口黑边与安全区、完整 Integration/Release 保持未验。本次有限 AI 布局判断不代签这些项目。

完整证据 SHA256、来源与限定范围见 `review-02.json`。
