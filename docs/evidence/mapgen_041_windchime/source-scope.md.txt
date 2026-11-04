# 0.4.1开发入口、完整起点钟门与CI输入复用

任务MAPGEN-HOST-WINDCHIME-041/CI-SELECTED-INPUTS-01，独立后续分支feature/mapgen-041-windchime-integration，从PR130精确9ba7d4b64b939f80168a3d7d1ef08fd32a5b6be8接续，不从main重做。当前main30e36c9abe223f26e666ceaf796e3fe9cb58e10f；保留PR127→128→129→130历史，最终用集成PR纳入所有修复，不分别强合失败中间head。

## 本轮明确授权

用户原话：“本轮解除此前‘A全部CI收尾后才允许开始B’的串行限制”；“授权在最终验收和审阅通过后普通合入main，保留提交历史”；“普通出发流程保持现状，不部署网站”。因此旧工作线只A/0.4.0/不合并的历史边界不限制本轮明确范围。旧结果不改签，新源新身份单列；不绕分支保护、不强推。

## 固定输入与模块范围

SDK交付commit c35871446cc0a3939e1a38171435f42cdc64a359，0.4.1 ZIP SHA256 f5c84e5e51dff01d16429783b957c0d5214056b9d2fea47a830baac12ecedb4e。manifest实际算法源码8eefdbd140ce10defe1570ab8eefb6729382f8b3与含包交付head分开。模块继续1.1.0/SHA5ad5a7871941b2c1ffa759b18f7b1e80f2fe7e571b72f95d1e0ef26031f08723，runtime-map/v2不变。先原0.4.0校验及基线保全，再原包19GD安装；不改vendor源码或复制算法。

完整game-plains-windchime-lesson/safe_lesson保持原平台、门、风铃、封口与永久开门语义。按module_id/content_version/role/实际连接选择，不M号。合法封未用Port不能因旧authored helper被挡而拒绝；原helper保来源，真实usedPort/身体净空/落脚/连接仍验，原几何/能力检查不关闭。复用ShotLatch、真实弹丸/Router、controller/lifetime、PlainsRegionState，所有玩家/伤害/钱包/奖励仍原权威，不抽装配随机数。

普通出发、物理/经济/资源/奖励/RNG、永久save schema不改；不模块1.1.1、不全部机制/敌人/奖励/Boss/整图。实际邻居有未支持内容时只报单模块，不能删邻内容伪造跨缝。

## 验收与交付

原PR130/run41679005631保持原head独立实收，输入恢复parallel45:16/serial49:42后才开始测试；若90min job超时分清输入准备占时和实际test fail，保存原已执行结果，不盲目整轮重跑。

CI最小修复：prepare同run/精确HEAD/实际原selected input manifest工件供lane与合流验证复用，保path/mode/Gitblob/SHA/source/完整性/nooverwrite/symlink/HEAD-index守门，原178检查、断言与单项预算不减。可见进度/分项时长，不建通用CI平台。

实际主工具链Godot4.7.2中0.4.1生成→Provider→Plan→Stage→Runtime；既有三模块/gears回归，钟门出生站稳、真实Router射击开门、重复命中幂等、走到真实出口接岸、状态恢复及取消/退出拒绝迟到提交。能力从真实controller/tuning取得，不额外授予/补资源。Web保持原两fresh/动作/所有断言/guards，自动与真实全截图离线审阅分开；原件丢失的必需部分可补跑，不补造。

小步提交推送，原始必要证据远端或SHA可核持久工件，大PCK不入源码Git。全部代码/证据冻结后一次最终候选完整CI；失败针对原因修复，无变化元数据不触整套。独审+必要验证+最终精确head CI通过后普通合main，不部署网站。main push自动Pages须采用明确的本轮不部署出口，保CI而不[skip ci]。

## 并行写集与生命周期

root统一Stage入口/selection/profile/任务质量/提交推送/单Godot与browser租约。sdk_041_upgrade仅SDK/install/job版本与其测试；v2_port_admission独占Provider/port helper及provider tests；windchime_runtime独占纯latch适配/运行组件/Stage及newrunner；ci_input_bundle独占production workflow/cloud_inputs及其测试；final_ci只读原run；stage_a_final_review只读独审。各writer不stage/commit，root有界协调提交，避免共享index。每条线及时保存持久recovery包。
