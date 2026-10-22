# 主线收口与并行开发基线

任务 MAIN-CLOSEOUT-20261022。用户要求快速把现状全部开发分支合main，再从main并行开发。森林未完成的艺术、网状拓扑、模块库、真人时长与设备验证保持原状态；这次只收开发历史与当前实现，不签产品完工。

所有源码head已在收口候选祖先，旧5个美术head的原commit/blob保留但不覆盖当前共享Underworld风格。15个orphan试玩分支和旧deploy/pr67只装网页产物，留作原包恢复。[完整盘点／独审／树相同证明](evidence/main_closeout_20261022/README.md)。已通过PR102合入main，合并SHA `9c349f44caa7e230b7784a340a839906cac58d0e`；[实际远端闭包](evidence/main_closeout_20261022/main-verification.json)确认全部源码head已包含。

后续每个主题从更新后的origin/main开分支，各用独立worktree，PR直接向main。共享入口、配置、skills和状态文档先分配负责者；合入前更新main并处理冲突。只跑受影响短检查，合入CI保持原标准。已合并旧head不再作为新开发基底，也不为收口批量删除旧分支。

公开试玩当前仍[e361原型](https://zhipijun1996.github.io/gunman-rush/?v=e361af714d54)，FOREST PLACES MAP1/2。main自动部署不是源码合并的等价物，另核对实际run/PCK/source，不能用URL查询参数恢复旧包。
