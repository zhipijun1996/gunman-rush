# 主线整合与原生发行

当前任务：用户授权合入PR150（feat/approved-platform-rooms）最终文件树并发布Android／Windows GitHub Release。输入为c721b20a及本轮必要的发行修复，main为其祖先，无并行功能冲突。游戏内容与局部体验证据归[平原交接](../plains_bible_v2_01/scope.md)，源码合并不代签完整主环、Boss平衡或设备表现。

## 清理与范围

不合入Web产物分支、录屏、截图、日志、生成批次和旧报告。逐项查新增素材的代码／场景／现行manifest引用，退休的人类NPC母版、旧钟心背景和全局草前景随本次差异删除；现行制作母版、原生tile、动态装载素材与许可保留，不能只按文件名含source或版本号删除。历史由Git保留，main只保留最终文件树。

## 原生发行规则

Windows x86_64和Android ARM64使用同一main提交及锁定Godot 4.7.2 gunman-sd1模板，版本归project.godot。受控资源清单与Web共用导出依赖解析器，原生仅含正式43房；工作台预览、试验房、mapgen和纯制作参考不进安装包，原有工作台不部署。必须使用release导出；打包与签名、包内容检查、平台实际启动分别记录。

Android新建独立发布签名已获用户确认，私钥及密码保存于仓库外私有位置；CI只传输明确未签名的release APK，最终公开附件须经本地签名、证书和SHA256检查。Windows ZIP包含EXE、同目录PCK与许可；发布前实际Windows启动，Android验证签名、ARM64、包标识、非debuggable及对齐，真机性能不由这些检查代签。操作入口及共享验证见[Harness](../../harness.md)。

## 结果与恢复

本轮构建、检查及附件记录写入ignored build/main-release、build/native和GitHub Actions。最终main合并、Release标签、两端附件及校验在完成后写回本段；公开网页版本及独立关卡平台状态仍归平原／工作台交接。
