# 前景重复计算修复

实现：`a5c5bcd72eef7b387e23d3b292da59dd6221fe82`，基线 `a38040c294aa541ed707bc50c55cf3769ecd7852`。

实际 CI 39995440179 的89条并行检查通过，串行17通过、森林整区600秒超时、35未执行；森林80条中仅45条完成原验证。没有把未执行记通过。

真实 Godot 脚本采样发现：Presentation 自动刷新和前景自身晚刷新重复计算保护/遮挡。现在只由前景原 priority2000 自动更新；显式 `refresh()` 默认仍即时更新。每次保护计算内只读取一次 viewport/canvas，原裁剪区域不相交的遮挡直接跳过。物理、输入、伤害、资源、随机、路线、断言及预算未修改。

这会改变早刷新可能产生的 sticky admission/entered-view/retirement 历史，不能称所有居民逐帧完全等价。原生命周期与遮挡测试分别验证；未代签美术、手感或设备。

## 实际验证

- 原 `tools/verify_foreground_continuity.gd` 真实 GL/llvmpipe，before/after 均退出0、506 samples、23 identities、246个前景像素样点。包括相机往返、身份稳定、只在离屏回收、手动刷新不走时钟、真实碰撞保护、恢复延迟和暂停风冻结。原 PNG/报告/日志随附。
- 独立提取原/新真实 helper：718次对照、0失败；包含触边、空/容纳/不相交矩形、三种实际 viewport/canvas transform 与原64碎片上限回退。脚本中的原绝对 scratch 路径为当时执行位置，原件与提取身份保留，不宣称提交后自动可重放。
- 同一 case09（seed `forest-depth-hollow-00`、map2、growth）、原3810帧/46腿输入、相同私有计时 runner、两逻辑CPU、LP_NUM_THREADS=1：29.3286 → 18.7045秒（减少36.2%）。这是本地单例测量，非GitHub或80条总成本承诺；测量源是 a380 加两文件 overlay，随后精确提交为 a5c5。
- 15项选定玩法字段逐字比较相同，包括Manifest/路线/完成段/请求/暂停菜单/奖励/保存状态/初末快照/音频释放；事件kind/tick/leg顺序相同。不是全视觉或全部原始帧等价声明。

原森林80条、精确最终CI及main状态以随后真实收据和PR106为准，本单例和元数据不签完整通过。已发布a074开发Preview保持原producer身份，不包含本次CPU修复。

`proof-index.json` 绑定原始与存储字节；`.json.gz` 是原报告无损压缩。新增style版本仅技术引用重绑，其他35引用、旧Bible、方向原件与用户引文保留。
