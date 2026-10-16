from pathlib import Path
import json,hashlib,subprocess,re,time
R=Path('/workspace/gunman-rush');B=R/'build/plains_redesign';E=R/'docs/evidence/plains_redesign/final_current';A=R/'docs/evidence/plains_redesign/acceptance'
idx=json.loads((E/'index.json').read_text());assert idx['status']=='portable_bytes_verified';members={m['original_path']:m for m in idx['members']}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def link(original,label):
 m=members[original];return f'[{label}](evidence/plains_redesign/final_current/{m["stored"]})'
s=(B/'final_delivery_working.md').read_text()
s=s.replace('**[待填最后文档/证据提交SHA。]**','最终文档/证据提交由PR67的实际commit记录确定；本报告保留原C3/C4运行来源，不把文档提交冒充重跑。')
design=json.loads((B/'final_design_review/finalization.json').read_text());visual=json.loads((B/'final_visual_review/finalization.json').read_text())
old='**[待填最终两份report SHA及completed_bounded_review标记；允许REJECT/UNVERIFIED，不要求品质ACCEPT。]**'
s=s.replace(old,'两份审查均已 completed_bounded_review，实际 verdict 均为 REJECT 完整品质完成声明。设计报告 SHA256 `'+design['report_sha256']+'`，视觉报告 `'+visual['report_sha256']+'`。标记完成指审查完成，不是内容通过。')
s=s.replace('**[待填portable index路径/SHA、最后提交和draft PR URL；目前不能称归档完成。]**','完整归档已逐文件校验原始/压缩SHA与解码往返：[portable index](evidence/plains_redesign/final_current/index.json)，index SHA256 `'+sha(E/'index.json')+'`。这只证明证据字节，不授予技术或品质PASS。PR67保持draft。')
s=s.replace('归档完成后，正文从','已完成的归档由正文从')
s=s.replace('原运行版本、审查版本和包装版本继续分别标注。','原运行版本、审查版本和包装版本继续分别标注。最终完整路径清单见[变更清单](evidence/plains_redesign/acceptance/changed_files.csv)。')
s+='\n\n## 可直接查看的实际证据\n\n'
s+='| 内容 | 旧版 | 当前候选 |\n| --- | --- | --- |\n'
for name,title in [('intro_fast','主路推进'),('creek_growth','溪谷探索/回营'),('advanced_deep','高收益路线'),('high_return','高奖回岔口')]:
 s+='| '+title+' | '+link(f'build/plains_redesign/matched_movies/before/{name}/gameplay.mp4','旧电影')+' | '+link(f'build/plains_redesign/matched_movies/after/{name}/gameplay.mp4','当前电影')+' |\n'
s+='\n'+link('build/plains_redesign/final_outer_movie/gameplay.mp4','原外环失败电影')+'；'+link('build/plains_redesign/worst_movie/gameplay.mp4','最差策略失败电影')+'；'+link('build/plains_redesign/outer_no_live_png_movie/gameplay.mp4','完整外环技术对照电影')+'。均为实际正常速度音画记录；录制的墙钟耗时不是游戏实时性能。没有完整音轨审听签收。\n\n'
s+=link('build/plains_redesign/final_design_review/report.md','独立设计审查原文')+'；'+link('build/plains_redesign/final_visual_review/report.md','独立视觉审查原文')+'；'+link('build/plains_redesign/final_regression_review/c4/closure.md','工程守卫范围接受')+'；'+link('build/plains_redesign/final_regression_review/c4/outer_no_live_png_review.md','录制失败与唯一对照审查')+'。Markdown原文保留为.md.source，避免将历史相对链接误当本轮导航。\n\n'
s+='### 地图与实际镜头\n\n以下地图由真实Manifest/geometry/轨迹投影，同一对使用共同坐标轴；不是游戏截图或美术验收。\n\n'
for side in ['before','after']:
 s+='!['+('旧版地图' if side=='before' else '当前候选地图')+'](evidence/plains_redesign/final_current/'+members[f'build/plains_redesign/controlled_maps/map_1_crossroads/{side}/map_1_crossroads.png']['stored']+')\n\n'
s+=link('build/plains_redesign/controlled_maps/index.json','全部六对地图索引及来源')+'。\n\n'
s+='![当前正式镜头，仍可见构图不足](evidence/plains_redesign/final_current/'+members['build/plains_redesign/matched_movies/after/creek_growth/frames/frame_002280.png']['stored']+')\n\n'
s+='### 复现与明确的停止原因\n\n完整恢复命令：`python3 docs/evidence/plains_redesign/final_current/restore.py --root /tmp/plains-observations-new`，目标必须新建，原件中的绝对路径作为历史保留，index映射仓库相对路径；不能直接把旧路径改到当前源后称重演。全部归档已解码校验，但没有在空间受限环境完整写出第二份隔离副本。旧地图应checkout基线30f并安装同19文件观察器，按保存request复演；当前内容v10不能消费旧v9 Manifest。\n\n'
s+='采用的[game-quality-gate](../.agents/skills/game-quality-gate/SKILL.md)要求：“预算、无进展、越界或外部工具依赖阻塞才保留现场并停止对应依赖。”[本轮冻结预算](quality/plains_redesign_iteration_budget.md)进一步明确：“新旧失败卡/源/原图/全部媒体不动，Q6完整目标仍failed。”两版旧素材构图和一次新资产均失败后，实际31次生产调用封账、剩余2不用。本轮保留候选而不继续重抽或把失败签成完成；下一轮具体方向见上方Prompt。无需用户替团队发现这些已知问题。\n'
assert '[待填' not in s
(R/'docs/plains_redesign_delivery.md').write_text(s)
header='''# 最新收口：平原可玩候选，完整品质目标未完成

2026-10-15；独立分支 `feature/plains-designed-exploration`，[草稿PR67](https://github.com/zhipijun1996/gunman-rush/pull/67)依赖PR66，未合并main、未发布。C4运行/观察冻结 `a39ea373105c24b09c59b9d51b7c440440bc0a17`；最后提交只收口文档、知识、质量元数据和证据，不冒充全局fresh原生检查。

已真实修改两图布局、主路短动作、侧岛奖励/同船回程、高奖敌位、外环与功能镜头/UI。相同19driver/133core/初始单PulseLv1能力，10root×两图×四策略，旧新各80：到目标51→71，0旧达新败，9双侧策略失败；共同完成51例低互动候选52→33，但伤害46→49，map2fast伤害4→10。设计与视觉独审均REJECT完整品质完成声明：悬空背景/重复轮廓、9条敌岸策略及双向公平风险保留。

C3实际deliver12/12，fresh49+22交集19、并集52，C4只改GUI定位测试工具且显式桥接；没有单次52/fullC4声明。GUI原8+7通过。11部电影和6对实际地图已留证，原livePNG外环3007tick/7断言1失败/exit1不变；同脚本只省实时PNG的唯一对照6528tick/8断言0失败，原因未知、非TTL已证。生产31calls封账，cap33余2不用。真人趣味/完整音画审美/实体设备/目标性能未验，父任务review且technical/G1与visual/G2保留failed。

[完整交付、实际命令、地图、电影与独立审查](plains_redesign_delivery.md)。森林仍仅按现有S2/H规则plan_only，H在Studio实现不等于正式授予或地区完成。以下旧段落为历史，不覆盖本段状态。

---

'''
for name in ['current_state.md','handoff.md','generation_current.md','procedural_generation.md']:
 p=R/'docs'/name;p.write_text(header+p.read_text())
p=R/'docs/tasks.md';t=p.read_text();lines=[]
for line in t.splitlines():
 if line.startswith('| PLAINS-REDESIGN-GUI-LOCATOR-01 |'):line=line.replace('| in_progress |','| done |')
 if line.startswith('| PLAINS-REDESIGN-Q6-ROLLBACK-01 |'):line=line.replace('| in_progress |','| review |')
 lines.append(line)
p.write_text('\n'.join(lines)+'\n')
A.mkdir(parents=True,exist_ok=True)
for key,title in [('final_design_review','independent_design.md'),('final_visual_review','independent_visual.md')]:
 # Human-readable navigation lives here; the immutable original remains in bundle.
 d=json.loads((B/key/'finalization.json').read_text());(A/title).write_text('# '+title+'\n\n判定：'+d['verdict']+' 完整品质完成声明。审查只覆盖原报告列明的实际观察。\n\n[原始报告](../final_current/'+members[f'build/plains_redesign/{key}/report.md']['stored']+')，SHA256 `'+d['report_sha256']+'`。\n')
print('Final report/navigation/task index written; no gameplay changes.')
