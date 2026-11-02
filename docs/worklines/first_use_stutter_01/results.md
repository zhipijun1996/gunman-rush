# 首次射击绘制准备：结果与边界

运行源 `b5c7bf65cf7a551cb0783f44f6fa594804bf94ee`，基点 `23ba7a79bbfca7f0f1662088f611911dbfd0725b`。这是小范围性能修复，不是新一轮全仓重构。main 未合入本批；PR122/124原内容保留，PR123排除。

## 实际修改

- `FocusVignette` 的屏幕效果原本就是 unshaded；显式排除世界点灯，避免不必要的灯光特化。原显隐、颜色、透明度、渐变和时间公式保持。
- `game/presentation/rendering/canvas_shader_preparation.gd` 由 Focus 和现有 UnderworldPresentation 两个实际消费者共用。它只在独立16×16 World2D提交临时绘制，正常提交后或宿主提前销毁时释放；headless不创建。
- 世界表现准备有灯／无灯的三角和线段，使用现有灯纹理，不预演射击、不创建游戏实体、不发声音、不消耗资源或随机数。
- style33／creative36仅技术重绑206项中的World一叶；其余205项及86个非GD资源字节保持。旧版本、失败、原断言和原预算保留。

## 实测

| 项目 | 实际结果 | 不能据此宣称 |
| --- | --- | --- |
| 原首次空中Focus | 4次shader编译／2次链接；重复为零 | 整段卡顿都由它造成 |
| V2预热 | 首air仍2／1，实际拒绝 | 预热已生效 |
| 当前诊断包真实Home输入 | jump、shot pulse各+1；首air所有program新增编译／链接0／0 | 手机FPS或全部正式敌战已解决 |
| 目标Canvas程序 | 准备出的lit三角／线段VS与FS逐SHA等于原正式首枪程序，且有准备绘制和后续Home消费；unlit也实际绘制 | 已完成新版本正式4发／3命中／1击杀采样 |
| 原生GPU | 50／0；真实点灯有效、正强度确实出像素、六次渐变逐像素等价、离屏无污染、正常与提前销毁清理；Dummy音频下无ERROR／泄漏 | 设备或用户视觉认可 |
| 同版相关Harness | 10项fresh／0复用／0失败；原钩索瞄准、UI、current46／history48／creative30、两绑定及docs／structure／quality | 新full171或Windows验收 |
| 实际导出PCK | 空目录原探针13／0，严格错误和泄漏检查，完整PCK前后SHA一致 | GPU或手机性能 |

Harness在提交前明确dirty源执行；其working-file向量已逐项核对等于冻结F，不冒称Git-clean CI。原测试typed WeakRef警告、ALSA环境错误、输出目录旧symlink拒绝、绑定失败及三次浏览器工具／门口路线失败均保留。缓存守门未放宽，旧影片alias仅移至verification之外，原影片未动。

## 构建与交付

- 原 `tools/build.py web`／包闭包／重建器均通过；使用固定Godot4.7.2 gunman_sd1和原debug Web模板，未切引擎或发布模式。
- 复用已验506 PCK中的精确56个Foundry派生输入，并真实经过原stamp；构建前clean SourceRoot与构建后“源＋明确派生56”分别留证，非派生字节全部保持。不将dirty派生覆盖签成SourceRoot clean，也不把本地包冒充CI API artifact。
- build `9dd3a9a2ecd8`；PCK `216394452`字节，完整SHA `9dd3a9a2ecd845d5728089693282e1642ab1efa2e1868e3925c637fbaa32e0e5`。
- prepared `2f0b308952145b4f8f522b10925782e4ae21f3ac`，仅原导出普通文件／chunks；完整重建后SHA与原包一致。
- Pages [41423846094](https://github.com/zhipijun1996/gunman-rush/actions/runs/41423846094) 成功；原公开验证器和独立完整64位SHA流式核验均通过，metadata前后一致。
- [公开试玩](https://zhipijun1996.github.io/gunman-rush/?v=9dd3a9a2ecd8) 的真实标题→Home→门→BEGIN→正式平原入口GUI通过（179.016秒／原300秒，13张截图逐张核验，无FPS04／init script／状态注入）；保留最后短移动下落画面，只签入口和输入响应，不签安全站立／生存／全路线／正式首枪性能。

## 仍未解决与下一步

原正式首命中帧220.431ms仍有未归因时间。其时所计时的compile/link/texture/readback未出现≥2ms慢调用；draw与buffer仅有调用计数，且脚本计时为嵌套批次，不能相加或归到一只怪物。优先补这些盲区及手机Chrome实际帧证据，不继续凭猜测改网格、声音或规则。

本轮性能诊断的正式30秒新采样未完成。普通最终包的入口烟测另行记录，不拿它代签正式首枪、命中／死亡帧或手机表现。设备、玩家、完整消费者盘点及最终formal integration仍未签，任务保持review。

公开回退使用上一prepared `f55e3cfc7d7867c672d76f5887fc3694c62502c8`（build506a4e40a1ee）；源码及绑定须成组回到23ba7基点，不单退一个GD。

重复导入缓存回收：仅删除与成功F构建工作树副本逐SHA一致的1684个生成缓存，净回收355999570字节；原图声、源码和影片未动。完整恢复清单在精选证据的 `build/import-cache-recovery.json.gz`；可按清单从构建工作树恢复，或用原editor import重建。
