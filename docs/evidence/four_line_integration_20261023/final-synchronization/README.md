# 当前集成验证收口

实现提交 `a861406e699e95553b56a7f1a53edbafe4da7cfd` 仅采纳四个已审测试文件；运行代码、五首原 MP3、物理、关卡及检查预算未变。完整下一轮 PR CI、main 合并及 Release 在本记录写入时尚未完成，不预填通过。

- [最终四文件采纳独审](final-adoption-review.json)：限定 ACCEPT；三项专项独审分别在 [BGM](bgm/independent-review.json)、[家园](home/independent-review.json)、[森林](forest/independent-review.json)。它们不签整区品质、人工或设备认可。
- [12f6 原 CI 报告](ci-12f6/attempt2-report.json.gz)：88 passed、BGM failed、53 not_run；另存首次依赖安装超时。失败不改签。
- `local-12f6` 四份原 Harness 报告合计补跑50项：47通过，家园与图一两路线失败。已通过的当前 encounter 完整检查归属12f6，不再沿用旧 full3 失败作为最新结论；旧失败原件仍保留。
- [BGM 实验与身份](bgm/handoff-final.json)：原89断言保留；真实单调时钟等待原200ms，15个正负控制通过。旧 SceneTreeTimer 同帧长任务后可在不足1ms返回，不能代表真实混音200ms。
- [家园身份](home/identity.json)：真实点击 ContinueAdventure → ChooseExistingProfile；新增一次真实点击使180→181，当前新人物五项守门加强，经济、12站及实际操作保留。capture190未执行。
- [森林四原 wrapper 身份](forest/handoff-final.json)：24/24、32/32、35/35、43/43，均 source_stable；图一保持原 R/HANG/R 来源和当前实际 R/HANG/J，跳跃按住至首射击自然释放；469..583连续腾空，584首次落在含原目标的同高度双support，未低地重启或额外授弹。公共 driver／reader 未改。
- [精确 a861 原 Harness](canonical-a861/report.json)：BGM89/0和家园181/0重新实际通过，原退出及来源守门保留；森林四条外部候选证明保留其真实12f6加单文件覆盖身份，不冒称a861 fresh。
- [公开真实 Preview、完整包和浏览器证据](preview-a074-delivered.md)：运行源仍为a074加原工具生成的56项Foundry输出，build d38c8a407473；后续仅工程／测试变动不重导出、不改签。
- [只读输入提效审计](efficiency/link-input-audit.md)：现有3.294GB物化中约1.864GB独占对象可研究避免仅为链接存在性而下载；未实现、未宣称节省网络量。当前未删除历史源证据／资产。后续应分开做Git存在性解析及批量对象读取，避免在集成继续扩框架。

[原件清单](proof-index.json)记录每件原路径、原字节SHA、保存路径和SHA；大JSON确定gzip无损压缩，已逐件解压核原SHA。恢复方法为解压保存文件并核对应raw_sha256；绝对工作区路径是原执行来源，不要求未来机器保有该路径。归档不是测试通过证明，结论以各原报告为准。
