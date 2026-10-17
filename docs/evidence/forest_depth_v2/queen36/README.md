# 棘冠女王36：完整正常影片与局部因果

FOREST-DEPTH-02。基于真实提交 `0dd1fba0bffba707d873155fc506f874d3651565` 加当时dirty runtime overlay，fresh复制2019个运行文件。10个女王生产文件与冻结31逐项SHA相同，仍为Definition6/schema13；本轮只修驾驶及读取因果。该候选显式pin实验v2、production_pool=false，默认v1不改。完整影片和技术验证不等于地区或Boss正式准入。

## 当前实际结果

| 证据 | 结果 | 输入与范围 |
| --- | --- | --- |
| [完整目的H影片](movies/adaptive_H/gameplay.mp4) | 1493帧，24.883秒，1492tick击杀，Player损1/E100 | 读预告借首结、主结借剪、普通换层回岸；不声称第三H成功 |
| [最强普通edge影片](movies/edge/gameplay.mp4) | 1116帧，18.600秒，1115tick击杀，Player损1/E80 | 无H、不剪结，真实瞄射/反冲和岸边纠偏，合法更快胜利 |
| rising局部 | 47/0，原Player5→4，仅第三网一伤 | 940实际P2低巢，974普通跳起，1007全身体落枝，1180第三网Policy，1343借剪返岸 |
| observer局部 | 22/0，Player始终5 | 普通输入避旧巡线，完整周期、真实主结借剪和输出/返岸 |

两片同一个冻结36源，同起态Boss24HP/Player5HP/E100。1280×720、真实正常60fps、完整原输入，无裁剪或游戏加速。软件GL实际采集H42.874秒、edge32.813秒，分别在单次60秒预算内。正常native120、cold import90预算未变。原23/24两次45秒采集超时原判保留；60秒是明确的软件采集预算修订，不是游戏设计时限。

[关键帧索引](keyframe-index.json)记录各PNG的原影片零基帧序及60fps时间。PNG均从对应未裁剪原AVI提取，MP4由该AVI转码。AVI保留build，不入Git，路径、SHA及大小在[总清单](artifact-inventory.json)。关键帧不代替整片审看。

## 来源、原始数据与复核

总清单列出每个文件SHA、大小、原位置及压缩前SHA。`*.json.gz`为无损gzip，mtime固定0；解压字节必须匹配original_sha256，不是重排或筛选后的原始JSON。两片原capture、native日志和receipt全部保留，input-timeline只是另附的事件选择，不能替代capture。`inventories/`保留fresh主源完整清单；两movie receipt还各保留完整2019文件before/after清单、原始argv、selector及source/verifier守卫。

`sources/`是13份冻结生产/验证源码的精确字节副本，统一加`.txt`防止Godot将证据当生产重复导入。`producers/`保存本轮实际copy、局部运行及movie采集脚本；实际影片参数与selector均在各receipt与总清单。source domain明确区分全2019运行源、level_formal消费子集和runner；不把clean Git HEAD冒称真实执行源。

局部因果从fixture最初HP取基线，不在挨伤后重取。跨口采用实际平台端点与完整24×36身体，保wholefoot guard，不能以通用walk的7px容差冒充完整支持。第三网压力须同时匹配其真实field_id/epoch事件前缀、accepted sweep与实际Policy应用ID，并且整次fixture只有这一伤。observer5HP无伤、完整周期/回岸、save畸形负例、H2→1与普通反向弹1→0都真实执行。

## 保留的失败与片段

`failures/`保留原失败raw/receipt/native，无损压缩不改字节或结论：

- movie23_H/movie24_H：原45秒软件GL超时，原fragment未成为完整影片。原AVI路径/SHA仅引用，不能因部分画面已击杀Boss而追签完整返岸或native结束。
- 32：188项、4失败；旧230落点进入新80缺口，观察驾驶忽略P1巡线，旧local无伤条件失败。原完整战斗与严格驻守消融的实际结果仍可按原scope引用。
- 33：41项、1失败；只改终点仍不能用纯walk横穿80缺口，真实落地网。
- 34b：43项、9失败；残留左移轴使等待时走下平台、地网连续致死，后续命令连锁失败；不是普通跨口本身不可行的证据。
- 35：14项、1失败；普通跳确实落枝，但通用walk容差让右脚超出约1.26px；另有真实身体754伤，不能算第三网压力。

离线因果审计也区分原32第三网444实际匹配、额外身体521令唯一伤条件失败，与原33地网439、35身体754完全不匹配第三网。不得把这些不同来源统一重标为驾驶或内容“通过”。34未运行的准备副本不是失败回合。

## 未完成的认可

本轮没有重新运行current最终all188；32原188/4fail不追签，36只补两local69/0。完整最终Harness仍待当前源执行。正式App自然入口/24HP战斗/fresh恢复/奖励/边界证据属于独立的[campaign Node边界包](../campaign_node_boundary01/README.md)，不拿本局部fixture代签正式消费者。31和36均为有限CONTINUE；[36不同作者整战独审](../reviews/queen36/REVIEW.md)认为当前候选值得进入playtest与技术整合，保留普通快法，不冒H3/P3完整巡回或每阶段持续深度。未签用户趣味、设备、音频、G2美术、完整Boss或默认地区准入。
