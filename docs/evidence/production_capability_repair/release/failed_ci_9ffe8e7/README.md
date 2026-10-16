# A4 实际完整 CI 失败，未部署

源码 `9ffe8e7c7d299a2d9cf710287c6c07e8c04b8385`，正式 [run38875599430/attempt1](https://github.com/zhipijun1996/gunman-rush/actions/runs/38875599430)。原 Harness 实际30通过、plains-action-golden失败、后30未执行，wall1248.788秒；core job1357秒是包含关系，不能相加。Windows/Web导出通过，部署和公开验证被跳过。

原错误为冻结v9恢复错误地复用当前已变化的 assets/manifest.json，原484资产指纹中仅这件变化。它是快照重建代码缺陷，与网络、Godot资源退出分开；不改冻结清单去掩盖失败。下一修复只从可携带原Gitblob恢复旧字节并继续校验原指纹。

ZIP含原CI Harness artifact、API终态run/jobs/artifact元数据及实际GET计时、原core日志、publisher退出与独审。索引记录原/portable SHA；原件未覆盖，扫描0处认证URL需脱敏。A4实际Web原包三GUI及同源native动作影片的有限技术接受另存，不冲销本次完整失败或签成公开发布。
