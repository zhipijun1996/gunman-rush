# PR111 主线合并与公开试玩收据

运行源码：`45e98dbbf38d906dc5eae9686dc9ee5ee6a99acc`（PR111 的正常 merge commit）。

试玩：<https://zhipijun1996.github.io/gunman-rush/?v=410d4fc7539a>

入口：开始游戏 → 家园东侧出发门 → 正式平原；暂停直接进入背包，左右翻页。家园原图鉴建筑提供发现记录、音符解锁与出发单选；宝箱、Boss 与商店获得的道具先入背包，需装备才生效。

`delivery-state.json` 记录本操作工作线的实际终态、后续交接和每件原证据的完整 SHA。合入提交中的任务卡是合并前快照，不能用其中的“待合并／发布”覆盖本收据，也不能把其中局部验证误当完整 CI。

- CI run40701501936 的真实来源为 PR head `09a900b2c1a60da0384688ad9e525534e6f4fe13`，165/165 fresh。两通道、最终汇总、原始日志与 API 收据保存在 `CI_FULL165.zip`，逐成员核对见 `ci-archive-index.json`。main 合并树与该通过树完全相同；没有把 CI 来源重标为 main。
- Web 使用原 `tools/build.py web` 从实际 main 重新导出，build `410d4fc7539a`，201,156,304 字节，完整 PCK SHA-256 `410d4fc7539a3c04d524a826e4792e74981334846a17758ac5377d7f9954150f`。分支预检的旧 `9ad5df1b5868` 包没有当作 main 发布。
- 复用同树 CI 实际验证的 Foundry 数据池作为导出输入；原 stamp 正常执行，没有手改 basis 或跳过守门。导出后原资源已逐字恢复，main 工作树保持干净。
- 发布工作流 run40714056550 / attempt1 成功，产物 ref `prepared/playtest-main-45e98dbb`，不可变产物提交 `95a77bf336da4b6c50e9f850fa7407cb2a003855`。超100MiB的原 PCK 由原分块工具重建，未裁掉资源。
- 原公网 verifier 通过；额外核对公开 PCK 的完整 SHA/长度，以及 HTML、metadata、cache worker、build report、许可证的逐字一致性。独审独立复取公开 metadata/cache worker，并审阅完整 EOF 核验生产过程。
- GUI 原收据、普通输入命令、准确 producer 与实际截图按各次运行单独保留。`functional_passed` 只表示所列游戏流程；整体缓存状态不可误称全部通过。触屏 Home 走路使用键盘，菜单／箭头／继续使用实际 touch，不能称完整移动多指或实体安卓验证。

已知限制：初始下载约200MB。旧同 loader 预检曾实际观察到80MiB缓存预算造成重载时全量分块下载；新 main 本轮 warm 未运行，历史失败按原来源保留，没有宣称缓存通过。默认浏览器 `/favicon.ico` 404 单列为非游戏错误，所有脚本／shader／游戏资源／页面错误仍严格检查。实体安卓、手柄、低端性能、听感、平衡及玩家 G5 未验。

该分支仅归档交付证据，不改变 main、已部署的资源包或游戏规则；公开试玩地址为可更新站点，不是历史不可变托管。
