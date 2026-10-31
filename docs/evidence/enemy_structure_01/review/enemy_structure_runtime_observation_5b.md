# ENEMY-STRUCTURE-01：5b最终候选的限定回归观察

2026-10-29，`/root/enemy_review`只读核对原报告／日志；Godot运行0、仓库写入0。当前HEAD为干净`5b083938ea9f2722fe6c44896914f9d2d198e87b`。本报告补充前期源码独审及5b文档闭包附录，不改写旧失败和旧源报告。

**当前已证实：5b结构runner和原命中／软件GL专项通过；4af原14项受影响矩阵全部fresh通过。维持结构源码与指定测试迁移限定ACCEPT；完整CI40844941490尚未签通过，怪物美术／动作质量与G5仍未通过。**

## 源与独立性

独立重核4af→8fd仅selector测试改变、8fd→5b仅7份docs；生产程序／场景／资源／素材／配置／shader／工具字节保持不变，原结构runner及motion fixture也不变。14项矩阵仍标其实际干净4af来源，不改签成5b fresh全量矩阵。此前独立selector21/0属于字节等同8fd的隔离候选；完整新head CI单列。

本代理编写了新结构runner/wrapper。下述730/39为root实际执行、我读原件核验的运行事实，**不构成对自写测试设计充分性的独立签字**，不据此自签全roster的状态／消费者覆盖已充分。生产代码diff与其他作者的旧测试迁移／selector修复是另一个独立审查范围。所有运行均由root持单引擎租约完成。

## 5b源实际专项

| 原件 | 观察结果 | 适用范围 |
|---|---|---|
| `build/enemy_structure/native-05/{report,runtime}.json`及native.log | passed，730检查／0失败，39/39case；before/after均干净5b，source_stable=true | 显式结构fixtures、状态快照、绑定、拒绝和生命周期；不证明合法完整战斗／GPU像素／动作质量 |
| `build/enemy_structure/gpu-and-hit-05/report.json` | 三条原命令退出0，before/after均干净5b，source_stable=true | 原命中模板426／0、实际software GL裁剪44／0、GL身体颜色隔离12／0 |

已读三份专项真实日志及各自runtime，无SCRIPT／SHADER／native ERROR或退出泄漏。裁剪GL为3family×5种位置／镜像15张输出：中心与边缘非空，outside均0；断言证明有限裁剪及生命周期谓词，不是全部怪物前后像素等价。颜色隔离12项记录ordinary body_changed821／HP变化0／world_cue变化0，Boss body_changed12159／弱点环变化0／world_cue变化0；这是颜色层隔离测试，不能评画面或动作好看。本次没有把数字报告叫作实际正常速度审片或听审。

native04真实失败仍保留：缺`fusion-pixel-12px-proportional-zh_hans.otf`导致资源／preload parse ERROR，wrapper退出失败。恢复输入后native05通过；我另核恢复字体5,050,076字节与5b Git对象逐字相同，SHA256 `db40edf0cc1e446bfe1ce75d5abb4d7c499ace96379b8a0f5f761bd3de8335eb`，不是改生产源或屏蔽错误取得通过。

## 原14项矩阵：精确4af源

原报告`build/verification/harness/20261029T083648.345807Z/report.json`实际status=passed、release=true、targeted_checks=true、commit=4af、工作树干净；14项均退出0、reused=false、无failure_reason，均在原预算内。独立逐读14份log，未见native/script/shader ERROR，原成功marker存在：

- core 5686／0；terrain-family全maps通过。
- 五feedback：native458／0、formal66／0、support199／0、corpse-save72／0、snapshot147／0。
- forest enemies、guardian full、guardian tolerance、Queen sweep、Canopy各原入口通过。Queen／Canopy输出自身仍注明机制价值／正式map2准入UNVERIFIED，不扩大它们的技术结论。
- underworld-continuous-bosses含原实际App两场完整战斗，map1为459帧／0失败，map2为801帧／0失败。
- forest-depth-region原80项corpus全部通过。实际receipt含80 requested／80 completed／0 not_executed、80 runs全passed、source_stable=true。10个原根Seed、两map与四路线保持；547.301秒／原600秒预算未放宽。

矩阵总墙钟846.481秒是14项总耗时，不能与80项专项547.301秒混写，也不是游戏FPS或目标设备性能。该矩阵是14项受影响选集，不是166项完整CI。

## 当前未关闭的范围

CI40844941490的parallel/serial尚待实际最终报告；此前40843714099 prepare失败保持原件。本轮本地docs／quality／diff通过据其独立原件另列，不与上述原生结果互代。

用户对旧怪物制作参差的拒绝保持有效。程序重构及回归绿灯不证明黄金单怪、美术档次、动作受力／节奏、正常速度带声全看、玩家反馈、物理设备或G5通过。完整CI结束后仅追加真实运行范围与精确source，不改这些边界。
