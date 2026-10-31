# DEMO-UI-01 独立复审

审查者：`/root/independent_review`，非实现作者。2026-10-22。只读源码与真实 Godot PNG；未运行引擎，未执行鼠标／触屏／手柄，未观看或听取连续影片，未验证公网或实体设备。本文件是审查者唯一写入文件。

审查基线为 `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`，候选尚未提交；不是对该基线未修改树的验收。复审所读源码子集 SHA256 汇总为 `0bd4fbed5c46fbf3e2f49b6a40fe7cf560a4cd41b480b5f6a52e3743a7fa8d3e`：按路径排序，将 DemoApp、HomeScene、DemoMenu、PlainsRegionMapModal、ItemShopModal、StageRewardModal、StageExitModal、RegionProgressionModal 及 `scripts/ui/demo_ui_01/*.gd` 的 `{路径: 文件SHA256}` 以 `json.dumps(sort_keys=True,separators=(',',':'))` 序列化后散列。

## 结论

**限定 ACCEPT：允许交付首轮可操作 UI 方向供用户评价。** 新标题、HUD 与结果页的桌面画面层级清楚，生命增长不再被调试按钮遮挡；没有发现对 Motor、伤害、资源、能力授予或地图拓扑规则的改写。该结论不代表商业美术定稿、完整 Integration／Release、浏览器／手机地图、用户或真机认可。

## 实际查看的像素

首审实际打开 `build/verification/demo-ui-contract-01/` 的 `title.png`、`formal-hud.png`、`max-growth.png`、`run-end.png`、`map.png`、`pause-844x390.png`。首审发现与失败范围保留，不以本次修正追认原图通过。

复审实际打开 `build/verification/demo-ui-contract-05/` 的 `title.png`、`formal-hud.png`、`hurt.png`、`map.png`、`max-growth.png`、`run-end.png`、`pause-844x390.png`。这些是原生静态画面，不证明完整动画、音轨或自然游玩路线；生命边界和死亡来自明确的正式消费者测试 fixture。

观察：标题以名称、主操作、钟盘形成可辨主次；HUD 去除左上大板，满心／失去生命、空中弹药与精力刻度能区分。`max-growth.png` 的 `4.25/13.5` 和两行爱心均可见。`hurt.png` 的当前 `4/5`、金色延迟失血单元和 `生命 -1` 对应同一状态。结果页将再次出发设为主操作。手机尺寸暂停图的按钮与文字比首审明显增大；当前焦点靠后的动作可见，标题可能因滚动处于屏外，属于长页滚动状态。

## 首审问题与修正核对

- **R1：地图恢复焦点可能将 A／Space 重新解释为开图。** 源码已在 `close_region_map`、`_resume_from_menu`、`_resume_exit_input` 释放 GUI 焦点；扩展地图画布禁用确认焦点。当前测试回执包含“关闭后第一次 A 不重开地图”。源码修正接受；本人未独立运行该路径。
- **R2：菜单之外弹窗／地图按钮仅有 52–54 逻辑像素，缩小后不足 48 实际像素。** 新共用 `DemoUiModalMetrics` 按真实 screen transform 设置目标尺寸、字体、安全区；Shell 和地图已消费；HUD 也新增缩放。原生暂停像素可见改善。实际 DOM 地图、浏览器 DPR 与实体安全区仍未验证，不能由公式或此图签全范围通过。
- **R3：共享弹窗／地图缺少焦点循环边界。** 新共用 `trap_focus` 为有效控件绑定 Tab／方向邻居，Range 与 OptionButton 保留横向编辑。源码修正接受；地图、商店、奖励、能力页的实际循环操作仍以宿主逐项测试为准。
- 生命增长数字遮挡：当前像素已清除 `i` 按钮遮挡。
- 英文标题不一致：共享弹窗现统一为 `THE CLOCK UNBOUND`。

## 回执边界

复审读取当时的 `build/verification/demo-ui-contract-05/assertions.json` 为 **94 checks / 0 failures**，SHA256 `d38e7507bd84e2bcfea9b7d822f9be5150c87042eb178263e5615600c773d708`。宿主另报告带截图运行 104 项；本文件不将当前 94 项 JSON 冒称 104 项。测试由宿主执行，独审只检查回执与源码，不宣称独立重跑。

## 剩余事项

- 原生静图无法签菜单过渡、受伤／恢复全过程、连续消耗／耗尽与音频；需真实影片和实际操作。
- 浏览器 DOM 触控／取消、实际地图手机尺寸、DPR、安全区与手柄实体测试继续保持未验。
- 既有外观选择器处于菜单上方的独立层，截图仍可见。它属于共享人物工作线，未要求本线越界修改；最终整体菜单审美可由用户评价。
- 目前是统一、可用的第一轮方向；面板造型仍较克制，是否足够有游戏氛围和是否需要进一步压缩 HUD 密度须由用户反馈决定。
