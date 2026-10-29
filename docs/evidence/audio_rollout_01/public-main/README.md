# 已选环境音 main 发布收据

PR113 已普通合并至 main `1b29932c5333a9dad50759afc635762163ed79f5`。实际 main 导出并通过原发布工作流上线：[试玩](https://zhipijun1996.github.io/gunman-rush/?build=618eb97114e6)。版本 `618eb97114e6`，完整 PCK 208,689,368 字节，SHA256 `618eb97114e6715fc33856823c9bf23141e8e51802a886596bc9f223ed7ca691`；公网完整字节、source/build 与8份音频许可/来源文件均核对。

采用 quiet-02 平原A／森林A和 home-quiet-01 家园life（底声额外−2dB、真实NPC处12–22秒／全局6秒／至多一条生活声）。五原BGM、SFX original与游戏规则保留；不顺带推广13项短SFX候选。

[主收据](receipt.json)记录CI、部署与验证边界。精确PR头 b6659cb1 的双通道91＋74共165项全部fresh通过、0复用，affected汇总成功；合并树逐字相同。原串行80路线600秒超时被保留，同head只重跑失败job，原80例／4工人／600秒下459.591秒通过。独审不追签原失败，见[超时审查](../review-ci-timeout.md)。

实际主场景原生45／0、导出26／0、原PNG30／0及Python2项通过。main实际包20份raw JSON/音频与16份正常音频导入派生逐项核验；它们与前置已验包字节相同。前置真实浏览器验证Home生活声、音量/恢复、正常平原/暂停/声音owner与显式森林A；不冒称森林自然通关。

公网实际标题点击→Home→真实D移动触发cloth1，原生混合PCM非零（最高0.032196）。[PCM摘录](public-home-pcm-excerpt.json)来自一个整体FAILED诊断，明确保留原status及SHA，不冒称完整脚本通过。[实际家园](public-home.png)仅是画面证据，音频另由原生输出旁路读取。旁路保留原扬声器连接，未生成声、未调用resume；其边界见[旁路代码](observer-used-for-home-pcm.js)。

公网完整GUI脚本未签通过：旧zero-gain旁路时有零采样；真实录音旁路已见非零混音，但“音量0＝整路精确零”的诊断观测到一个1/32768样本。原GameAudio/GameMusic保留最低电平，不能等同Master硬静音；未降低原阈值或修改游戏迎合测试。原失败摘要分别保留，原始报告仍在本地build/audio_rollout_01/public-web-qa-01..04。仅确认所选床在音量0时暂停；Master开关及完整公网跨区脚本未代签。

实体手机/iOS Safari、低帧率软件GPU下连续听感与商业品质仍未验证，用户试听选择不等于这些验收。源码已经在main；此后续纯文档分支只保存发布之后才能产生的收据，不改变已发布游戏。工作区resources/foundry的差异为原工具按本轮源码重建的已验证开发缓存，不提交为新玩法。
