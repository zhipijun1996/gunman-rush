# ASSET-METADATA-LAYOUT-01：三条当前登记SHA修复

实际主树已应用assets/manifest.json三条既有primary SHA修复；本目录仅准备其质量记录跟进，不再次改源码。[质量卡](../../quality/records/ASSET-METADATA-LAYOUT-01.json)绑定11254a6647dbb4d842feb4d21de9e2d8bd9accd3基点与当前manifest62a1c2a8… WIP。只改索引261、267、271的SHA，310条id/path/顺序/其他字段、content_version、历史source_sha256、许可/生成与冻结旧接受原件均保留。

三当前JSON只曾在功能目录迁移中改五处consumer路径；现有asset_records及style27早已使用当前scenery/terrainSHA，此次补既有assets authority遗漏，不新造资产表或重生成图声。非作者[独审](../../evidence/game_architecture_02/asset-metadata-layout-01/review/independent-review.json)确认三hash可精确逆变换原manifest；1041media路径/Gitblob与2ce相同，作者实际581123832bytes流SHA收据一致，独审未重复全读媒体。不是新视觉/音效/用户认可。

root原Harness [实际报告](../../evidence/game_architecture_02/asset-metadata-layout-01/root-targeted/report.json)中art-art完整310assets freshpassed，0.399秒/原120秒，原checker未改；同报告后续art-plains_v3因稀疏catalog缺件失败，原日志原件保留，整体报告仍failed。该后续缺件归另一个consumer任务，不能把本局部通过扩成整体batch通过。

原remote41195033622失败不追改；full185、其他lane、实际导出/公开交付、GUI/设备及主观审美仍未验，工作流in_progress。最终提交身份由root收口后绑定，原WIP运行来源不变。


## 两条既有中央登记记录的技术来源后继

原三SHA合法修复后唯一assets/manifest.json为62a1c2a8…，但demo_ui_01_r2_registry与fine-space-05-asset-registry仍绑定旧ffca09…，原Harness quality实际报两项source hash mismatch。本次不重写图声生成证明：仅两既有production_record_only记录source_sha256改为真实当前manifest，并追加technical_followup说明及原件引用。原content_version、revision_impact、生成/许可/视觉状态、所有旧条目和用户接受证据完整保持；source_path继续指唯一assets/manifest.json，不新建registry或素材记录。

指定feature-layout-before-style26/original_current_metadata归档实际是更早0a02/b090记录和476f manifest，并非本次当前原4dfd/8726及旧ffca。该归档原件保持，本次仅另存两当前原记录及精确11254 Git的ffca manifest为.source，避免错误声称旧归档完全等于当前父版本。

[有限绑定证明](../../evidence/game_architecture_02/asset-metadata-layout-01/registry-followup/binding-proof.json)核当前manifest仅三既有row.sha256变化，310行其余字段/顺序/ID相同。1041媒体字节一致性复用先前已归档实际流SHA/独审证据，本次没有再生成、替换或重验听感，也不追签视觉/设备/用户通过。

原命令python3 tools/check_quality.py按原60秒预算直接前后执行（targeted，不是全Harness）：主树前测exit1同两SHA失败；完整外部overlay后测exit0。首次外部镜像漏嵌套docs evidence/build六文件而失败的日志原样保留；补齐原字节后通过，没有修改检查器。主树应用/非作者最终独审仍待，不把外部静态通过写成全185或图声接受。

后继两record已获[非作者限定审查](../../evidence/game_architecture_02/asset-metadata-layout-01/registry-followup/independent-review.json)：只sourceSHA和technical_followup，其余原字段及原父字节保持，原quality60结果收据/日志核实。审查不代签全部文档包、艺术、媒体或full185，主树应用与复验仍由root执行。
