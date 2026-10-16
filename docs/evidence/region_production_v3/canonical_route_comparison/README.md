# 正式路线实际对照（事实证据，未签美术通过）

直接下载并播放 [PR68原始录像](pr68_gameplay.mp4) 和 [V3当前原始录像](v3_current_gameplay.mp4)。若GitHub只显示文件信息，点击Download raw file；下载后用浏览器或本地播放器打开MP4。两份都是原始正常速度录像，未重新编码。

先阅读[对照报告](report.md)，再查看`comparison_video_frame_*.jpg`：上中下依次PR68、V3改藤前、V3当前。相同video frame index不是physics tick。PR68→V3非纯美术隔离实验，原严格guard拒绝结果保留。本人是ivy实现者，本包只是事实包装，审美与ivy独立审查须由他人承担。

下载并解压`original_records_and_png.zip`即可获得三侧原capture、完整源码指纹、18张未修改PNG、原日志与严格比较记录。无需拼接文件；两个MP4单独提供，ZIP不重复包含它们。`portable_packaging_receipt.json`列出每个文件原路径、大小、SHA和新ZIP CRC/逐member验证结果；`index.json`保留原始build归档历史，其original_evidence.zip引用指向仍保留的build旧包，并非这里需要下载的文件。

`*.summary.json`与`*.raw_deepdiff.jsonl.gz`保留可计算差异；后者可用任意gzip工具解压为逐行JSON。当前路线只覆盖实际高地、维修营地与下层溪谷，没有钟庭/Boss空间覆盖证明。
