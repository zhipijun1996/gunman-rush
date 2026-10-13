# 首轮独立严格审查：否决与修复

独立代理 foundry_review；2026-10-12。本文件保留初审否决，不把最初内存验证的成功冒充交付可玩。

1. **否决**：JSON.parse_string 将整数读为float，原始checksum和expected比较失败。磁盘批次显示24条但实际无法加载。修复：规范数字和键顺序，验证磁盘往返与落盘输入回放。
2. **否决**：Lab是PAUSABLE，暂停后Esc不被处理。修复：ALWAYS UI节点负责快捷键，世界保持PAUSABLE；复审实际Esc恢复通过。
3. **否决**：移动平台回放节点与验证器入口不同，两种船模板在第516帧偏差2.133px并停止；其余四模板误差0。修复：真实回放接入同一physics_frame入口，不放宽2px误差阈值；扩大实际Lab测试至六类模板。
4. 稳健性要求：验证basis覆盖相关生成/输入/玩家/driver/验证器；坏反馈数据清洗、有界500条和临时文件替换；回放独占adapter并恢复。均已实现，复测另存。
5. 来源：初版引用尚未观察的费耶山片段，下载空文件不能作为学习证据。重新下载并采样观察前置跑图和第一段雪山衔接，保留实际长度不足与不确定性；不宣称完整游戏已分析。
6. 范围：二跳/四发profile是兼容验证，未有专属四发挑战；钩子disabled。正式Run/Meta与模块池不变。自动可通过性不等于好玩。

初始6段轨迹证据见 [initial_trace.txt](initial_trace.txt)，旧basis被拒绝见 [rejected_stale_batch.txt](rejected_stale_batch.txt)，YouTube下载失败见 [youtube_download_failure.txt](youtube_download_failure.txt)。

导出阶段另发现JSON未打入包、编译包无法重算源码hash及中文字体缺字。显式包含JSON、受源码校验保护的export stamp和字体子集修复后，实际浏览器两种输入回放与评价下载通过。导出指纹的依赖覆盖否决与复审见 [export_review.md](export_review.md)。
