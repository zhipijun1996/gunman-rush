# 同源全检查的两段CI执行

这是现有Harness的执行编排修复，不是新关卡生产系统，也不签森林趣味／设备／商业品质。原完整0cf CI仍失败；新分段全CI尚未执行。

时间证据见[timing/REVIEW.md](timing/REVIEW.md)：0cf前缀wall2569.618秒，加有来源的剩余命令样本约64.565分钟，尚有19项缺测／其它开销。样本跨源和机器，不证明当前必超，但存在明确原60min风险；不靠weights或重复长跑碰运气。

沿原`tools/harness.py`新增可选`--lane parallel|serial`，原默认执行路径和每check预算／marker／sourceguards保持。当前gameplay+art的85个ID严格分为67与18，分别在独立机器原60min内运行一次，jobs1／release，不复用缓存；五个原像素／音频附加检查仅串行一次。原其它job与部署接口保持。

`--verify-lanes`必须在同源／同prepared-foundry输入的checkout重新核完整source SHA、Git／manifest／profile／toolchain、原argv／caps／digest／新鲜token和原stdout SHA／marker／严格错误。缺项、重复、混源、旧缓存、伪partial、缺／改日志及budget变更均拒；仅两段完整技术证明才允许aggregate core成功。单phase明确partial，不可当完整profile认可；device／fun保持unverified。

[harness/README.md](harness/README.md)及原完整33unit最终6.805秒通过，包含真实临时Git和Python子进程的phase→merge正／负例；原25tests／execute_checks AST不变。这个单元层事实不冒称Godot／实际CI。workflow目录保留YAML／34 shell语法、实际collector文件I/O五例、原5附加命令不变、非core结构相等、原publisher13unit／11.238秒通过的原件。

源码冻结后由不同作者绑定immutable Git审查；独立审查记录后续加入本目录。最终完整同源85+附加／Windows／Web／发布必须以实际CI为准；不能根据离线切分计数宣称全通过。

两份reclaim收据只清终态可重建import缓存，每个源码／原素材／raw／日志／电影／原ZIP保持。它们不签任何新执行。
