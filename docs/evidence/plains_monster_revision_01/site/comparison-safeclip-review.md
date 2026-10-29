# Comparison catalog safe interval · 限定独立审查

**ACCEPT，仅限comparison_variants对首个展示页的一个前导观测帧作明确排除。** 审查者`/root/revision_evidence_prepare`未实现该补丁；只运行/tmp纯Python函数回归及ffprobe，未写Game/Site，未运行Godot。不是网页发布、数据库、整套catalog或怪物视觉接受。

实际源为clean7edda9f5f2a20c5406391ff3f7edebbeb2322047的comparison03。原trace page0连续300行9..308，声明可播放10..308；后5页300行均严格首尾等于声明。补丁保留原声明播放边界和原trace/movie字节，只允许逻辑page0的第一实际观测恰好start-1，选可播放row10作poster。proof保observed_frames300、actual_first_observation9、declared start10/end308和excluded[9]，且原traceSHA可重建全部300连续观测；因此没有把299个可播放帧冒称300个播放帧，也没有把初始状态转换搬到别的时点。它处理的是已实际存在的一帧保守裁片差异，不扩大为任意偏移或放弃区间守门。

实际回归46项／0失败：真实6页正例，逐页原clip/action边界、首可播放poster、完整观测与排除proof；18个篡改反例分别覆盖初页2帧偏移、非首page前导、缺帧/重复（包括同步篡改计数）、倒序、尾部越界/不合、声明早于实际、非整帧、计数错、source/dirtyhead/manifest/disclosure错误，全部以ValueError拒绝。并核helper、原trace、原MP4与原report运行前后字节未变。原数据不回写。

输出的poster basis字符串仍泛称“First actual comparison-page movie process frame”；实际数值是第一可播放frame10，proof明确原第一观测9。建议以后精确写“First actual frame inside declared playback interval”，属文案澄清，不影响本补丁数值忠实性和本次限定接受。

复现：`python3 /tmp/plains_comparison_safeclip_regression.py`。报告为`/tmp/plains_comparison_safeclip_regression_report.json`，所有正反例逐项保留。测试identity使用原MP4的实际ffprobe/SHA与本地fileURI作格式输入，不声明该URI是发布地址，未绕过正式helper main对Git media提交等外层检查。

```json
{
  "helper_sha256": "de1ea3b91a2770cf67b0b84e8184db72d1e771132934e3ed9517588143687791",
  "trace_sha256": "7f9adf56177cc6319a63795830da0431e415080c2aa93c939b5f44cea2de6732",
  "movie_sha256": "4956488e5a56b58c456fa919291c8b6f57950fc1f3c9c10c1480f3d2e5347ea4",
  "report_sha256": "1e55fdb677e556660129f8e29d1792085f10a8fa97bcace50b80a229ce0ebfea"
}
```
