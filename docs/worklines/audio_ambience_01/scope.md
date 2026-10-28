# AUDIO-AMBIENCE-01 · 两区环境音首轮

- 目标：让风铃平原和荆棘森林在静止与移动时有自然、克制、有地区识别的空间底色，动作、拾取与用户BGM清楚可辨。
- 基线：origin/main `45e98dbbf38d906dc5eae9686dc9ee5ee6a99acc`（含PR109和PR111）；分支 `feature/audio-ambience-01`；工作树 `/workspace/gunman-ambience`。
- 模式：Creative Exploration → System Engineering。先两区各A/B黄金候选，不批量扩产地区/Boss，不改五首原MP3、已选动作、物理、伤害、输入、资源、玩法RNG或存档。
- 使用Skills：audio-director、game-quality-gate、animation-vfx、region-creative-director、project-integration；手机工坊复用现有Sites并保持原访问权限。
- 写集：素材作者负责 `tools/audio_ambience_design.py`、`config/audio_director/ambience/{recipes,sources}.json`、`assets/audio/ambience_v1/`、对应Python测试和来源文档；运行作者负责GameAudio拥有的GameAmbience、运行专项和规范；场景作者负责独立dev场景、MovieMaker录屏、打包HTML；主控负责上下文路由、质量/任务/交接、审计、测试、发布与PR。独审仅阅读生产源和实证，不编辑所审代码。
- 接口：显式开发配置，正式original默认不变；复用Ambience总线/会话音量，独立有界持续声voice预算与既有12短SFX池明确列出；暂停/owner失效/死亡/换区/退出停止，不改变原消费者规则。
- 验证：相关最小Python加工/反例、原严格音频runner、新生命周期、原已选声音和旧森林环境回归；`production_plan.py --stage development --base 45e98dbbf38d906dc5eae9686dc9ee5ee6a99acc`选实际影响。相关输入预检/真实执行分开，未执行不写通过。
- 交付：两区同Seed/输入/镜头original/A/B真实Godot原音轨MP4，至少一个BGM实际混音对照；手机网页可播放、循环、单听素材、看许可、保存/导出选择，保留完整游戏旧入口并明确旧运行源。新Godot lab可进一步操作；观察型首轮以MP4为主要审美依据，不用旧Web包冒充新声。
- 体验假设：A偏清透远风/草叶，B偏近树冠/木质细节；最终以真实获许可录音的选材结果命名，不仅用响度/EQ区分。稀疏地标声有真实宿主或明确录屏fixture位置，不把奖励声当环境铃。
- 失败条件：明显拼接、循环抽吸、连续高音疲劳、淹没动作/BGM、暂停跨场景漏音、来源许可不明、同Seed动作漂移、视频静图配音或源码漂移。
- 验收：技术/AI专业判断/用户听感/实体设备分记。候选质量未经用户试听；本轮独立PR面向main，不自行合并。

## 当前检查点

已读取两区完整原Bible、风格与用户选择。素材筛选/运行/实际场景并行制作；主控独占Godot引擎租约。真实命令、失败与媒体指纹在 `build/audio_ambience_01`；精选证据进入 `docs/evidence/audio_ambience_01`。下次恢复先核分支、写集和进程，再读该目录README，不重做旧工作。

## 交付检查点 · 2026-10-28

运行/完整影片源de6b36c62f0640d9322973fffb687472755d25b7，Sites源8d29d15465fab8cd3e2856d130373fb35a2dd8ad；[交付与全部失败](../../evidence/audio_ambience_01/README.md)。首轮候选/6×26秒实景/12手机章节和实际许可加工已完成，原生脚本与原音轨/source/loop后验通过，独审工程ACCEPT；内容review，用户听感/实体设备/整套CI/正式推广未签。开发分支面向main，默认不合并；PR号及远端状态以最后交接为准。

[已发布手机试听](https://clock-ambience-lab.zhipijun1996.chatgpt.site/)，需拥有者账号；完整MP4与ZIP可直接下载。原BGM和起跳/落地不改，原forest短风在所有对照保留，点声库尚未自动布全图。下一动作是消费用户选择并迭代真实空间混音；不能因技术通过自行认定审美通过。
