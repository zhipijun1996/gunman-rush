# 主线收口（MAIN-CLOSEOUT-20261022）

用户明确授权把现状所有开发分支合并main，再从main并行开发。[原话](user-request.json)不是整区美术/趣味/设备认可。

[完整盘点](branches-before.json)：110个实际远端refs，含main；93个历史开发head中87已进旧main、森林最新1条和旧美术5条此前未进main。15条orphan playtest和1条deploy/pr67仅为构建产物，不合源码。所有本地开发head也已包含在候选。

森林767627f87e7f2b79a1cd79b7bd507e6df76b170d正常合并；旧demo、biome（含painterly/title）、v3通过3个普通ours merge保留原commit/blob祖先，维持当前画风与当前runtime，见[逐步原树比对](history-merges.json)。每步整个Git tree与767627f8完全相同。[只读独审](branch-review.md)及其原始JSON/复现程序保留；33个旧素材/预览/文档/helper路径此前从未在main出现，不能声称已经删除；现经祖先保留后可用git show HEAD_OF_OLD_BRANCH:path准确恢复，不启用旧画风或旧工作流。

[基线完整CI39734737843](baseline-ci-run.json)实际success，准确源767627f8；[原job步骤](baseline-ci-jobs.json)包括两fresh核心通道、原coverage汇总、Web与Windows。不是本地新调用或新main fresh证明；history merges只改Git祖先，合并过程的源码/运行树未改。原API artifacts身份见[清单](baseline-ci-artifacts.json)。原森林33项开发反馈超时和ART_REWORK依旧不变，当前CI默认集合不包含所有候选开发反馈。

最新文档检查、main实际合入SHA和远端祖先闭包由本任务后续收口回执补齐；不得把候选准备当已合main。公开试玩仍e361af714d54，source263afd；main自动发布须另以实际run/build结果为准。

原CI合并proof ZIP下载遇到403，未取得原ZIP，不冒称本地重验其内部计数／日志；[失败边界](artifact-download.json)保留，签名URL不入Git。CI成功结论来自精确run与全部job步骤API回执。
