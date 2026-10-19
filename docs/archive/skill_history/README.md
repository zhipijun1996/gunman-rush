# Skill历史按需归档

这里保存重构前16个Skill逐字原件；manifest.json记录原始SHA256与字节量，原证据和原运行记录不重写。当前职责入口为仓库AGENTS和当前Skill；旧轮授权不覆盖用户新指令，历史冻结规范仅约束对应旧版本。

| Skill | 原始字节 | 当前字节 | 已抽离历史章节 |
| --- | ---: | ---: | --- |
| [ability-creator](baseline/ability-creator/SKILL.md.source) | 6070 | 6586 | 仅精简重复共同契约，专属章节保留 |
| [animation-vfx](baseline/animation-vfx/SKILL.md.source) | 9349 | 9010 | 仅精简重复共同契约，专属章节保留 |
| [art-director](baseline/art-director/SKILL.md.source) | 18940 | 15947 | 透明度量与真实采样的因果边界；PR69真实家族生产修复（2026-10-16） |
| [boss-creator](baseline/boss-creator/SKILL.md.source) | 4986 | 4647 | 仅精简重复共同契约，专属章节保留 |
| [challenge-choreographer](baseline/challenge-choreographer/SKILL.md.source) | 10840 | 10471 | 仅精简重复共同契约，专属章节保留 |
| [encounter-director](baseline/encounter-director/SKILL.md.source) | 16189 | 14873 | V3真实缺陷修复：完整活体返程与资源不利相位 |
| [enemy-creator](baseline/enemy-creator/SKILL.md.source) | 7991 | 7652 | 仅精简重复共同契约，专属章节保留 |
| [game-quality-gate](baseline/game-quality-gate/SKILL.md.source) | 19817 | 18591 | 仅精简重复共同契约，专属章节保留 |
| [gameplay-reviewer](baseline/gameplay-reviewer/SKILL.md.source) | 15552 | 14330 | 仅精简重复共同契约，专属章节保留 |
| [level-module-creator](baseline/level-module-creator/SKILL.md.source) | 10414 | 9193 | 仅精简重复共同契约，专属章节保留 |
| [player-creator](baseline/player-creator/SKILL.md.source) | 5345 | 5861 | 仅精简重复共同契约，专属章节保留 |
| [project-integration](baseline/project-integration/SKILL.md.source) | 4140 | 4656 | 仅精简重复共同契约，专属章节保留 |
| [region-generator](baseline/region-generator/SKILL.md.source) | 22787 | 20722 | 平原整区重设计范围（2026-10-15，覆盖旧轮有限切片范围） |
| [scene-composer](baseline/scene-composer/SKILL.md.source) | 16526 | 15586 | 透明度量与真实采样的因果边界 |
| [visual-director](baseline/visual-director/SKILL.md.source) | 10412 | 9766 | PR69后的真实产出与验证成本 |
| [weapon-creator](baseline/weapon-creator/SKILL.md.source) | 7342 | 7858 | 仅精简重复共同契约，专属章节保留 |

原件有相对链接时，以原来的 `.agents/skills/<skill>/SKILL.md` 位置解释；必要时按manifest SHA校验后在独立冻结checkout恢复。归档不是当前生产依赖，不默认注入Agent prompt。

原16Skill总字节 186,700 → 175,749；该数字只衡量原16份当前默认文本，不含新增前置Skill、档案或链接文档，不代表token、运行时间或包体积。

新增唯一前置region-creative-director为3,513 bytes；当前17份Skill合计179,262 bytes，相对旧16份186,700 bytes净减7,438 bytes（3.98%）。公共创作入口另计；未声称实际prompt、token、执行时间或构建资源包减少。原专业规则的合并由当前创作入口承接，既有质量/证据记录仍绑定其原始Skill SHA。
