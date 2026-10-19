# S1 发布证据预归档草案（当前CI已失败，未发布）

后续：[历史authority修复及原360秒实际PASS](ROOT_BELL_REPAIR.md)已封存，165/0、40历史原串和40当前15%分别验收，生产玩法源码未改。这是S1加明确测试改动的真实本地原件，不重标成未来提交native重跑；新提交完整CI／发布仍待。

当前终态：S1选定CI39194694146实际failure，publisher ci_failed/deploy skipped。新增失败包和s1-failure-README.md记录本地authority失配定位。以下原预检只是此前局部已完成范围，不能当最终成功。

源码 S1：7ba2e92d2c3cb5449ac6648b820f79679548ee89；唯一选定 CI：39194694146。这里只归档已完成的局部证据，不含完整终态 CI 或本轮公开 GUI，不声明89检查、原80/600秒或发布通过。

s1-preflight-originals.zip 保留正确 clean worktree 的 docs22 原报告/日志、G0 提交树证据路径检查、2127 native 输入与 S1 Git 对象绑定、重复 CI 取消、诚实未完成质量结果及不同作者 commit-bound consumer review/probe。逐成员 SHA/大小及 ZIP 完整读回见索引。既有 local_docs22_originals.zip 不变，拟拷贝时避免重复。

地点必须准确：docs22 在 /workspace/gunman-grapple-docs-check 正确 clean worktree 中 PASS；G0 实际在 main repo 运行，原件位于 main build/verification/release-evidence。请求的 worktree 同路径不存在，来源映射已记录。错误 cwd 命令退出143中断，未生成 report，仅保留原 interruption JSON，不补造报告。

G0 仅证明73卡/614条提交树证据路径无缺失，不是质量门槛或趣味通过。docs22不代完整CI；native绑定不改旧raw.source_head、不冒新S1原生重跑；consumer review不签机制价值、全七句必经或玩家/设备。质量结果仍未完成、parent仍REVISE，上层路线吸引力缺口与便宜尾部替代均保留。

pending_CI_metadata 下原API只是当时in-progress元数据。单次serial下载403收据为已脱敏stderr、exit1/0.638秒/无文件，不是下载到的原报告，也未审其raw。失败保留，不重复下载或绕过。

不复制live publisher checkpoint、签名URL、token。未来追加真实CI/lane/stdout、preparedFoundry差异、API摘要原ZIP、同包浏览器/公开GUI或blocked收据时，单独绑定源/包和状态，不补签缺失事实。若原件含签名URL须保private build，另记明确脱敏派生与原/派生双SHA。

copy-plan.json 是拟拷贝到 docs/evidence/forest_grapple02/release01 的路径与SHA，目前没有执行拷贝、写tracked或提交。留空间追加实际CI/公开证据，再由root决定正式收录；本整理未启动engine、full tests或浏览器。
