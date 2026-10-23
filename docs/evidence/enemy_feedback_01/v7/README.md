# ENEMY-FEEDBACK-01 · v7 死亡音效

用户明确要求“怪物死亡应该增加一个音效”，解除此前仅死亡声音的暂缓。仍只charger/diver两个样板，复用同一个正式EnemyActor._on_death→GameAudio.cue(enemy_defeat)；没有另接死亡监听或再播放第二声。当前运行源0e37e04528b4f71af75e74c5370d656e1e122588。

[14秒带新死亡声的实弹短片](movies/after.mp4) · [20秒v6/v7声音对照](movies/comparison.mp4) · [单独音效](../../../../assets/audio/enemy_feedback_01/death_burst.wav)。全部保原速与真实音轨；新片与v6的1560玩法投影及输入/shot/HP事件投影相等，6次实弹HP提交/2次死亡，源稳定。显式Courier/简单地面fixture，不称正式路线或真机体验。

## 原死亡链与最小接口

具体共享接口与当前用户授权依据见[音色接口](../../../enemy_feedback_01_audio_interface.md)。GameAudio只在enemy_defeat读取Actor自己的AudioStream覆盖，继续原cue id、55ms共享节流、12声池、音量、暂停和weakref/shutdown。两套Presentation分别配置任务helper，helper只选流、不播放；弱owner token保护安装器/重叠卸载，保留原external配置及别的cue entry。默认enemy_defeat和所有kenney文件/Actor/Definition/AI/碰撞/伤害/击退/掉落/Boss/原死亡时钟只读。未配置对象沿旧音色，同帧多死仍可能被原55ms/12声策略合并，不承诺放宽预算后每死独立起声。

新WAV为48kHz mono PCM16、0.36秒、峰值约-1dBFS、零削波/非有限/首末跳变。以现有Kenney CC0木质轻/重及软体撞击，加明确记录的确定性宽带碎裂噪声，组成短干裂起音/躯体冲击/颗粒尾；没有使用phaser/提示音素材。完整来源、原件SHA、配方和许可在任务asset目录。source作者builder原字节在builder-original.py，SHA与provenance一致；可移植tools/build_enemy_feedback_01_death_audio.py实际重建WAV逐字节相同。原素材作者时点source_commit为本地v6交付a325（与公开334同tree），不是后补冒称新游戏运行源。

实录全26秒AAC双声道实际解码测量：v6峰值-6.374dBFS，v7 -5.225dBFS，两者超过满幅样本数均0；不是真人听感/耳机/扬声器/延迟验收。新声音在素材与音轨存在不等于用户认可，本次给可听候选。

## 保留的真实失败

首新test因helper的Variant比较布尔推断未显式标类型，导致依赖加载失败：126项/41失败及SCRIPT ERROR/退出leak；修显式bool后不追认为通过。第二次原fixed-fps快速离线跑239/16失败，原12声池被尚未按墙钟释放的旧音占满，死亡cue拒绝，不能以HP成功冒充有声。两次log/JSON原件分别保留first-failed/second-failed。最终同一测试改用正常物理/音频墙钟的--max-fps60（不设fixed-fps）真实247/0；没有清空声音、停掉生产声音、放宽池/等待/断言或补发死亡声。影片仍由原MovieMaker fixed60真实混音采集，单列验证。

## 交付范围

沿animation-vfx与game-quality-gate；本轮只为新死亡声改任务表现配置及必要的既有音频入口，不扩AI/行为或enemy-creator生产。v6夸张VFX完全保留；枪声与普通命中声仍暂缓。完整运动帧/整体美术、全受影响Integration、用户实际听感/设备仍欠缺，保留草稿不合main；中央任务索引由总控持有。

## 最终独审与证据

[独立报告](review.md)：新源native370/0、正常时钟death_audio247/0、formal62/0、audio生命周期37/0、实际GPU162/0、接口UNIT31/0，均exit0；原四Harness2872/0、317/0、96/0、54/0全fresh。1890份tracked代码/测试/tools/任务音频源hash前后未变，clean0e37。森林inner13条ERROR是EXPECTED REFUSAL畸形存档负例，原日志保留affected/forest-inner-native.log；不宣称所有原Harness日志零ERROR。

independent为精选直接回执；independent-originals.tar.gz包含完整本轮观察目录、音频生命周期内层原日志和实际GPU collector PNG/sidecar，逐成员SHA/大小见MANIFEST，全部读回验证。current-pixels是旧采集器目录名，本次源0e37；v6的空间扩大测量不重标为v7重跑。独审接受仅为接口与真实发声/生命周期技术范围，不签试听、设备或完整Integration。

[精确运行源包](runtime-source.bundle)依赖公开v6提交3342680c74b05349554d0e2cb5ee056c5131bc22，实际Git包已verify；已有此前提交的克隆可git fetch此包后checkout0e37。发布提交元数据可能不同，最终tree逐项匹配本地交付；不把文档发布SHA当录制源。

最终选定原docs Harness fresh passed（exit0），不冒称docs全profile；check_quality.py仍exit1，中央索引planned与本线review不一致由总控同步。单卡一致性errors=[]、整体REJECT；完整Integration和真人/设备听感等未完成。development-plan保留未知依赖保守full计划，实际本轮执行范围以原始检查/退出码为准；不合main。
