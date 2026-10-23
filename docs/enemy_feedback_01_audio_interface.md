# ENEMY-FEEDBACK-01 · 死亡音色接口（v7）

最新用户明确要求“怪物死亡应该增加一个音效”，本轮将先前audio deferred仅对两个样板的死亡声解除；枪声、普通受击声、Boss与全局素材仍不变。本请求需要通用音频所有者的最小接口扩展，先列此具体接口/影响，再实施可审查补丁；不新增Actor信号或另播一层声音。

现有唯一触发已存在：EnemyActor._on_death → GameAudio.cue(origin, enemy_defeat)，restore dead在_restoring_instance内跳过。本轮不改Actor/死亡/奖励链。GameAudio.cue仅对enemy_defeat读取origin上的audio_cue_stream_overrides字典；合法AudioStream覆盖传给现有play的可选参数，未配置/非法配置回原素材。play继续用同cue id、原55ms节流、12 voice上限、音量/暂停/弱引用/释放。其他cue不读此配置。

新增任务helper仅选择音色，不播放声音；EnemyPresentation和UnderworldEnemy分别为既有两种Definition配置此helper，退出只恢复自己拥有的entry/释放origin引用。安装器先remove旧Presentation再添加Underworld，旧配置已撤销后新配置接管；不接第二套damaged/died监听、不改正式安装器。材质/动作/死亡特效沿v6。

新任务WAV来自已在仓库的CC0实体冲击素材与明确记录的确定性碎裂噪声，来源/处理/哈希在assets/audio/enemy_feedback_01。只配置两个样板，不覆盖共享kenney文件。用户此前觉得声音太电子，本次目标为短干裂起音、低频躯体和快速颗粒尾；技术/音轨计数不代签真人听感。

复验：两物种×两链真实Router三弹→单次enemy_defeat新流；普通命中/旧epoch/重复/restore dead不增加死亡声；默认App掉落与重载、原音频池shutdown/原正式消费者、带原音轨同条件实弹影片。完整Integration/用户听感/设备仍单列未验。任务专属记录与媒体见本轮v7检查点，中央任务与主线不由本线更改。
