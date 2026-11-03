# 风铃Web工具v2最小API修复独立审查

限定 **ACCEPT** 冻结v2进入真实风铃补跑；没有签真实v2 Web、九图或手机／性能。审阅者 `/root/web_default_image_review` 与作者 `/root/windchime_browser_api_fix` 不同；不启动浏览器／Godot，不修改被审源码、PCK或工具。

实际导入已安装 Playwright 并用 inspect.signature 核查：Mouse.click 与 Mouse.move 均无 timeout 关键字。因此v1真实 TypeError 是工具API兼容错误，原90.3786秒失败、此前出生／门阻挡及guard事实保留，不变成通过。

v2仅在windchime_driver.py和其确定性生成器中，将原move+非法click替换成同一协程中的 move、click(delay=100)，再由 asyncio.wait_for(..., timeout=remaining(15000)/1000.0) 包住二者。逆字节恢复与全部assert AST一致；原两fresh／动作／9图／完整source、PCK、producer和HTTP守门／总300秒及外层watchdog不变。default/gears和三份offline工具、prepare均原字节一致，旧结果无需重跑。

独立47项源码／真实API／字节与AST核查全部通过。独立27项pure实跑16.602秒／0失败；严格fake Mouse方法也拒绝旧timeout，成功参数绑定真实API，聚合鼠标超时及API错误均走FAILED并关闭browser，未写成功动作或继续开火，strictjoin拒绝。pure是明确假浏览器，不能代签实际Playwright动作；标准asyncio取消行为与原失败清理维持有界路径。测试后全部冻结成员长度与SHA再核0变化。

冻结SHA见review.json。root须用此独立v2工具目录、新输出目录在同真实a0a9006源码／PCK上补跑风铃；保留v1全失败，不重跑默认／gears。真实九张PNG到齐后必须另行实际逐图审阅并严格合流，自动执行与离线审图计时分开。
