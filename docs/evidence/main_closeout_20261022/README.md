# 主线收口（MAIN-CLOSEOUT-20261022）

用户明确授权把现状所有开发分支合并main，再从main并行开发。[原话](user-request.json)不是整区美术/趣味/设备认可。

[完整盘点](branches-before.json)：110个实际远端refs，含main；93个历史开发head中87已进旧main、森林最新1条和旧美术5条此前未进main。15条orphan playtest和1条deploy/pr67仅为构建产物，不合源码。所有本地开发head也已包含在候选。

森林767627f87e7f2b79a1cd79b7bd507e6df76b170d正常合并；旧demo、biome（含painterly/title）、v3通过3个普通ours merge保留原commit/blob祖先，维持当前画风与当前runtime，见[逐步原树比对](history-merges.json)。每步整个Git tree与767627f8完全相同。[只读独审](branch-review.md)及其原始JSON/复现程序保留；33个旧素材/预览/文档/helper路径此前从未在main出现，不能声称已经删除；现经祖先保留后可用git show HEAD_OF_OLD_BRANCH:path准确恢复，不启用旧画风或旧工作流。

[基线完整CI39734737843](baseline-ci-run.json)实际success，准确源767627f8；[原job步骤](baseline-ci-jobs.json)包括两fresh核心通道、原coverage汇总、Web与Windows。不是本地新调用或新main fresh证明；history merges只改Git祖先，合并过程的源码/运行树未改。原API artifacts身份见[清单](baseline-ci-artifacts.json)。原森林33项开发反馈超时和ART_REWORK依旧不变，当前CI默认集合不包含所有候选开发反馈。

[PR102](https://github.com/zhipijun1996/gunman-rush/pull/102)已普通merge成功，main提交 `9c349f44caa7e230b7784a340a839906cac58d0e`，PR101也已标merged。实测[远端闭包](main-verification.json)95个源码refs（含main／新integration）全部为main祖先，所有本地开发head也均包含，main整个文件树与候选2c31c00e完全相同。首次93个历史开发head均已收口，部署产物排除。公开试玩仍e361af714d54，source263afd；main自动发布须另以实际run/build结果为准。

原CI合并proof ZIP下载遇到403，未取得原ZIP，不冒称本地重验其内部计数／日志；[失败边界](artifact-download.json)保留，签名URL不入Git。CI成功结论来自精确run与全部job步骤API回执。

## 完成回执

[fresh文档29项报告](docs-report.json)实际全部passed，精确候选2c31c00e，源稳定；不重签新main的fresh核心CI。[12个运行／测试／工具／workflow子树](candidate-equivalence.json)与成功767627f8一致，合main没有冲突后玩法改写。全部原docs日志、源守卫、API合入和逐ref证明在finalization.zip与[逐成员SHA](finalization-index.json)，已完整读回。

新main的[Godot core39741355698](https://github.com/zhipijun1996/gunman-rush/actions/runs/39741355698)／[Documentation39741355652](https://github.com/zhipijun1996/gunman-rush/actions/runs/39741355652)已自动触发，此时尚在执行，不能以基线成功替换其结论。后续纯文档收据提交跳过重复CI，不取消既有main回归；新文档提交不是该CI或PCK源。

旧森林ART_REWORK与其他内容任务保持原状态。这里完成的是Git/流程收口，已合分支不删除；新任务从origin/main独立开分支，PR直接向main。
