# 平原精修真实浏览器验证

最终本地包 `39edfde252ed`（运行修复 `f1105db`，测量工具 `6c50876`）实际 Chromium WebGL 检查 **8项通过、退出码0**。报告和截图在忽略目录 `build/verification/plains-polish-browser/`，实际日志为 `shader-fixed-run.log`，完整结果为 `browser-report.json`。

## 命令和范围

```sh
timeout 260 python3 tools/verify_plains_polish_browser.py http://127.0.0.1:8778/
```

可追加公开URL；无参数时启动本地 `build/web` 服务器。内部总预算240秒，失败非零；需要 Playwright、Chromium、Pillow与Tesseract。启动/刷新最多45秒等待真实标题像素，NPC最多30秒观察提示并小步行走，面板最多10秒等待标题。网络下载结束不作为游戏就绪证据。

使用真实键盘/触屏、截图和OCR，不读取引擎状态、不传送、不修改游戏脚本。9音符只在隔离浏览器首次加载时写入合法SaveService fixture，用于购买验证，不作为游戏赚币证据。

本次实际通过：

1. 标题ENTER HOME进入真实安全家园，显示fixture的9音符。
2. 真实Motor走到工匠、W交互、点击永久升级，9→4音符、vitality1。
3. 真正reload、重新进入家园并走到工匠，仍4音符与升级1，同包ID一致。
4. 真实行走到出发门、打开面板，进入正式COMBAT / ROOM1 OF10。
5. 普通移动与短跳产生实际世界画面变化。
6. 普通行走/短跳真实拾取音符，NOTES4→5；未注入这一奖励。
7. 暂停菜单确认返家仍5，真正reload并进入家园后仍5，同包一致。
8. 全路径无script/page/shader错误。

## 实际画面

`room-entry.png` 为灰蓝雾化远景，草色平台/危险/角色保留更强颜色。无HUD区 `(700,180,1000,400)` 平均RGB最大最小通道跨度从旧蓝包102.97降为16.63，证明去饱和真正作用于WebGL输出。

`room-jump.png` 远云块匹配dx=-10、dy=0、MSE0.641，同一前景平台右边缘约x947→702（约-245px）。不同位移证明真实相对视差，不以截图变化本身代替。角色屏幕高约55px，镜头观看倍率1.6，世界碰撞不变。观察保存于 `visual-observations-shader-fixed.json`，旧蓝包观察保留为 `visual-observations.json`。

另一次有界普通输入枪口抓帧实际完成跳跃/着陆/释放射击，并看到金色弹体；软件GPU截帧间隔超过短时粒子寿命，未清楚隔离扬尘/枪口粒子。其报告在 `build/verification/plains-vfx-browser/report.json`，粒子视觉继续待验，不能以组件测试或运动截图变化冒充。

## 历史失败与修复

| 实际失败 | 修复与保留证据 |
| --- | --- |
| Home OCR范围混入背景 | 使用真实Notes区域；`first-ocr-failure.json` |
| 焦点按钮白字浅金底无法读/定位 | 深色focus/pressed文字；`second-focus-ocr-failure.json` |
| 面板下W释放事件丢失，下次交互被旧阻断 | Home恢复仅解除实际已松开的物理键；`third-panel-release-failure.json` |
| 固定行走时长未到NPC | 观察真实提示有界小步行走；`fourth-fixed-movement-failure.json` |
| networkidle+800ms仍是启动Logo | 改真实标题像素就绪轮询；`fifth-startup-ready-failure.json` |
| 99包6项流程成功但背景仍蓝 | shader fragment COLOR重复乘原纹理；改vertex tint，新39包8项成功。旧成功范围保留`pre-shader-six-pass.json` |

没有降低原验收目标或把失败改报成功。色彩指标不代表用户认可最终美术；SwiftShader是实际WebGL软件管线，不能代替手机硬件GPU。完整十关人工通关、Android/iPhone Safari、实体手柄、粒子视觉与性能继续单独待验；本地与公开包证据分别记录。

## 公开网页验证

CI源提交 `6c50876` 发布后，真实公开URL `https://zhipijun1996.github.io/gunman-rush/?v=6c50876` 单次有界GUI运行 **exit0，8项全部通过**。实际浏览器读取包ID **`5f12c2d13996`**，不是本地 `39edfde252ed` 包；初次购买、升级刷新、出发门、真正拾取音符4→5、确认返家5、真正刷新后5、同包复核和无脚本/着色器错误均实际完成。9音符购买fixture与新增1音符真实拾取证据继续分开。

公共截图 `build/verification/plains-polish-browser-public/room-entry.png` 显示去饱和灰蓝雾化远景，背景RGB通道差16.6305；`room-jump.png` 同一云块位移dx=-9、dy=0、MSE0.376，前景同一平台边缘约x947→712（约-235px），实际视差成立，角色约55屏幕像素高。公开报告、完整日志及截图保存在独立 `build/verification/plains-polish-browser-public/`；此前本地最终8项目录完整复制到 `build/verification/plains-polish-browser-local-final/`，不会互相覆盖。独立粒子表现、真机Android/iPhone Safari和用户主观视觉认可仍待验。
