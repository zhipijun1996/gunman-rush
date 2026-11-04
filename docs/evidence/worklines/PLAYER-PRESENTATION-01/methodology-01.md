# PLAYER-PRESENTATION-01 · 表现方法研究 01

2026-10-22；用户本轮追加允许参考网络上的高级感、手感与打击感方法。以下为公开开发者原文阅读与本项目的**设计推论**，不是已经实现或用户认可。未观看所链接演讲的完整视频；GDC Vault 本次打开跳转维护页，不以搜索摘要冒充已读演讲。

## 采用的公开依据

| 公开原文 | 实际读到的方法 | 本任务推论 |
| --- | --- | --- |
| Riot：[Clarity in League](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/) | 玩法信息、重要性层次、降低噪声；剪影应表达角色与朝向 | 身体、武器方向、伤害提示分层；主要反馈集中在事件瞬间，恢复后清楚回到当前状态 |
| Riot：[How the VALORANT Arsenal was built](https://playvalorant.com/en-gb/news/dev/how-the-valorant-arsenal-was-built/) | 武器有可辨识的动作节拍；动画节拍表达当前状态与何时就绪 | 九种mode分别表达节奏，beam、投掷、回刃、布置物各自读得懂；不全套复用recoil |
| Riot：[The Craft and Fantasy of VALORANT Weapon Skins](https://playvalorant.com/en-us/news/dev/the-craft-and-fantasy-of-valorant-weapon-skins/) | 保留基础武器关键节拍与实际玩法，特效不干扰信息；音效绑定玩法关键点 | 不增加起手延迟、不更改发射时刻或真实枪口；视听创作不能改变既有accepted事件与资源 |
| Blizzard动画团队：[Weekly Recall: Animation Station](https://news.blizzard.com/en-us/article/24239492/weekly-recall-animation-station) | 先完善常用基础动作，再做复杂大招；角色动作语言应符合身份，持续playtest | 先修移动／首枪／恢复／受伤，再扩十五件装备；保留三外观自己的比例与动作性格 |
| Autodesk对Riot动画师的第一方访谈：[How Riot Games Animates VALORANT Weapon Skins](https://blogs.autodesk.com/media-and-entertainment/2026/10/20/riot-games-animates-valorant-with-autodesk-maya/) | 急促动作与短暂收势、关键时点清晰、代表武器先定方向再复用曲线；仅改跑步帧节奏也会影响速度感 | 尝试“快响应、可读峰值、受控回稳”的表现曲线；移动速度感必须靠真实相同Motor轨迹的对照验证 |

另定位了 Martin Jonasson／Petri Purho 的 [Juice It or Lose It](https://www.gdcvault.com/play/1016487/juice-it-or-lose) 与作者主页 [Petri Purho](https://petripurho.com/)，以及 Jan Willem Nijman 作者主页所列 [The Art of Screenshake](https://www.jwaaaap.com/)。当前只作为后续观看索引，不据此声称已采纳具体演讲技术。项目不复制第三方图像／音效／代码；保持现有许可与像素母版。

## 把主观目标变成可评审的画面

| 用户目标 | 本项目的具体设计判断（提案） | 如何推翻它 |
| --- | --- | --- |
| 高级感 | 剪影、脚底、握持、枪口与材质一致；反馈有主次，结束有明确收势；三外观仍可辨认 | 真实游戏比例下武器与手脱开、脚底滑动、三外观趋同、闪光遮身体／落点，或关掉表现后反而更清楚 |
| 手感 | accepted事件在下一可用绘制帧内得到响应；首枪后动作可靠恢复，移动与瞄准分层 | 输入已接受但没有反馈、recoil卡住、切方向突跳、受伤后旧反冲补播；任何玩法轨迹差异也失败 |
| 打击感 | 射击／真实命中／受伤三个因果分别表达；峰值方向跟随真实事件，回稳有节奏，力度符合现有武器身份 | 空枪出现命中反应、拒绝射击也演出、普通轻事件压过死亡／危险提示，或所有武器都表现为同一种抖动 |

这些是评审维度，不是“高级感得分”。下一绘制帧是本样板的工程目标，需要新增视频帧／physics tick映射实测；本轮基线没有该映射，不能追认已满足。

## 样板落实次序

1. 先消除已复现的生命周期错误：三外观首枪后有恢复，受伤可中断，死亡优先，暂停／epoch／卸载不会重播旧事件。保持唯一状态推进者。
2. 复用身体帧与武器catalog，使身体朝向与武器瞄准独立，上身绘制锁定现有权威枪口。动画可以弯曲／收势，玩法发射位置与时刻不变。
3. 仅在上身表现 Profile 内比较曲线：A 为快速响应、平稳回收；B 为快速响应、短暂强调峰值后回稳。它们都是纯表现假设，不暂停时间／Motor／子弹，不加入新的攻击前摇。时长先沿既有表现时序取基线，配置值经实片比选，不引用所谓通用最佳毫秒数。
4. 同源同Seed同输入同镜头录制 Profile关闭／A／B；先逐tick核对玩法相同，再看正常速度影片。增加“只去掉收势／只去掉武器差异”的消融，检查哪个细节真正改善辨识与连贯。不能同时改镜头、音量和粒子再把收益全归给上身。
5. 用真实正式Underworld及home替代外观各复验；代表样板通过总控接口／style评审后再扩全部装备。玩家最终选哪个曲线仍待实际试玩，不用开发者文章代签。

## 武器语言与职责边界

枪械以现有accepted弹包节拍表达短促发力；持续激光读取既有beam方向和起止；手里剑／回旋刃表达出手、在外、返航、接回与手中有无；炸弹／地雷表达布置与离手；奇点／Lv3技能按实际charge/skill阶段表达，结束可靠回到移动层。这些是按本项目已有武器规则推导的候选，当前没有“全部已完成”的证据。

hit-stop、输入缓冲／coyote time、反冲物理调整、命中判定、弹速、时间倍率均超出本线。镜头震动、通用音频／混音、新敌人命中反馈与正式UI归对应所有者；可提交协作建议，不在当前三脚本写集内擅自实现。对本线而言，发射反馈只能由accepted shot触发，真实命中反馈只能由accepted hit触发。

本研究补充已有[检查点](checkpoint-01.md)与[影响分析](impact-v1.json)，不解除共享四件绑定的总控独审／显式重绑要求；用户手感、审美、听感与实体设备仍未验。
