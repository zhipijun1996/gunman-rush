# 会话交接

2026-10-09 UTC。当前分支feature/snappy-shot-burst；本轮可变跳高实现提交48aa90bd7713f4f57f000dbb795313b7fc634b13，之后仅补证据文档；最终HEAD以git log -1为准。[PR #14](https://github.com/zhipijun1996/gunman-rush/pull/14) base=feature/core02-combat-controls，依赖未合并#13/#12；main仍64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226。未自动合并、强推或覆盖他人。

用户要求短按小跳/长按大跳、参考社区HK预设，后续Android和iPhone使用网页快速迭代。本轮已实现，完整规格/来源/测量见[可变跳高报告](variable_jump_report.md)。默认330横速、[-666,-732.6]跳速、min4/60/max9/60秒持有、800落速上限；重力2600与射击1100×.14秒不变。所有设备聚合持有/释放，取消不伪造正常释放；有效新跳跃立即接管爆发，射击不被跳跃释放削弱。

## 验证与发布

Godot4.7.2 Standard和匹配模板实际可执行。综合295断言/0失败，退出0；原254全保留。短按/长按峰高41.566/162.910px。Web导出实际0、Chromium151手机触屏模拟真实启动0，无脚本错误。文档检查22份/13依赖通过，py_compile与git diff --check退出0。故意失败入口--verify-failure-exit本轮实测退出1。当前改动没有重新导出APK，保留旧APK为历史，不宣称含本轮玩法；Windows由本轮CI独立构建。

用户已解除github-pages分支限制，环境当前无保护规则/分支限制；旧失败run37912890527仅重跑失败job后全success，公开入口HTTP200。本轮实现的[push CI 37915515468](https://github.com/zhipijun1996/gunman-rush/actions/runs/37915515468)整体success：core295/0与Windows导出success、Web导出success、deploy_web success；Android按新流程skipped。文档CI同样success。最新[公开试玩](https://zhipijun1996.github.io/gunman-rush/?v=5c72ebb0639a)已实测HTTP200，build-info与HTML均指向5c72ebb0639a，公开PCK实际下载SHA256为5c72ebb0639a600a451b0285945914ec6e53820485216ca1618c54dd4fef040f。Chromium151手机触屏模拟在公开链接真实加载同指纹PCK（200）并启动Godot4.7.2，无脚本/页面错误；逐帧采样实际观察短按与长按产生不同跳高（人物顶边594→491与594→431；浏览器注入不是确定性物理采样，不替代41.566/162.910自动峰高）。[Windows CI包](https://github.com/zhipijun1996/gunman-rush/actions/runs/37915515468/artifacts/11609378154)、[Web CI文件](https://github.com/zhipijun1996/gunman-rush/actions/runs/37915515468/artifacts/11609722564)保留7天。正常push不构建APK，保留可选手动/本地导出，不改变核心共享逻辑。

## 未验证与下一任务

iPhone Safari和Android真实触控/横屏/安全区域/性能、新手感、固定挑战动作链/20–30秒目标/3次通关/60fps/p95/20分钟稳定性仍awaiting-device；Windows实机/实体手柄、A27完整跨宽高比轨迹矩阵未验证。美术音乐、敌人/Boss、持久存档/Steam未开展。Cloud安装/启动配置界面发布仍按environment.md待用户，当前安装可用。

先在同一Web入口取得用户短按/长按和下射反馈，修复手感与固定挑战验收问题；真实固定挑战通过前不推进GEN-01，不承诺后台无限运行。

```sh
python3 tools/check_docs.py
python3 tools/run_tests.py
python3 tools/build.py web
python3 tools/build.py windows
# 仅需要原生包时：
python3 tools/build.py android
```

新环境先按environment.md运行cloud_setup/cloud_start，使用Godot wrapper而非系统旧版本。所有网络/进程设超时。
