# 主线整合与原生发行

正式平原内容通过[PR150](https://github.com/zhipijun1996/gunman-rush/pull/150)以最终文件树合入main，合并提交`32a11154684a8b2d7453fb9c08e4b618713a74f5`。本轮只将最终实现压为一个main提交，保留有效制作源与许可；游戏内容与体验检查仍归[平原交接](../plains_bible_v2_01/scope.md)。源码合并不代签完整主环、Boss平衡或实体设备表现。

## 清理与范围

不合入Web产物分支、录屏、截图、日志、生成批次和旧报告。逐项查新增素材的代码／场景／现行manifest引用，退休的人类NPC母版、旧钟心背景和全局草前景随本次差异删除；现行制作母版、原生tile、动态装载素材与许可保留，不能只按文件名含source或版本号删除。历史由Git保留，main只保留最终文件树。

## 原生发行规则

Windows x86_64和Android ARM64使用同一main提交及锁定Godot 4.7.2 gunman-sd1模板，版本归project.godot。受控资源清单与Web共用导出依赖解析器，原生仅含正式43房；工作台预览、试验房、mapgen和纯制作参考不进安装包，原有工作台不部署。必须使用release导出；打包与签名、包内容检查、平台实际启动分别记录。

Android新建独立发布签名已获用户确认，私钥及密码保存于仓库外私有位置；CI只传输明确未签名的release APK，最终公开附件须经本地签名、证书和SHA256检查。Windows ZIP包含EXE、同目录PCK与许可；发布前实际Windows启动，Android验证签名、ARM64、包标识、非debuggable及对齐，真机性能不由这些检查代签。操作入口及共享验证见[Harness](../../harness.md)。

## 结果与恢复

[GitHub Release v0.1.0](https://github.com/zhipijun1996/gunman-rush/releases/tag/v0.1.0)分发Android ARM64 APK、Windows x86_64 ZIP、许可、统一release-manifest及SHA256SUMS。两端运行内容固定同一main提交；构建入口为[原生发行工作流](https://github.com/zhipijun1996/gunman-rush/actions/workflows/native-release.yml)，最终源码SHA、运行号、附件SHA、签名证书指纹及检查结果以Release中的release-manifest.json为准。发行图标直接复用现有主角站姿参考原图，不重绘或改变角色比例。

合并前CI四项、文档检查、4项原生资源／预设检查、2项原素材导出检查、正式UI17断言、地图3721断言及独立PCK的43房／动态角色与特效／暂停指引装载通过。正式资源解析不包含旧Demo入口、实验室及工作台预览；共用地图手势／投影归MapViewport，风效用现有接地元数据识别景物，不再通过旧Stage类型引入实验依赖。发行额验main同源构建、实际Windows无界面启动、APK对齐／非debuggable／ARM64及apksigner签名；Android真机与Windows完整可视游玩未验。

日志与临时包归ignored build/main-release和build/native；私有Android密钥与密码仅在仓库外的私有目录保留，权限为仅所有者可读，后续版本必须复用。当前公开Web试玩保留独立版本9800cdf6933b及其原发行来源；本轮不部署关卡平台。
