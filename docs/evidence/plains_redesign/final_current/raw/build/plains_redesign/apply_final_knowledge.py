"""Final source-backed production lesson clarification; run only AFTER captures finish."""
from pathlib import Path
import hashlib,json
R=Path('/workspace/gunman-rush');B=R/'build/plains_redesign'
assert json.loads((B/'worst_movie_v2_execution.json').read_text())['status']=='recorded'
E=R/'docs/evidence/plains_redesign/final_current';index=json.loads((E/'index.json').read_text())
members={m['original_path']:m for m in index['members']}
report=members['build/plains_redesign/asset_contract_calibration/report.md']
metrics=members['build/plains_redesign/asset_contract_calibration/metrics.json']
report_path='docs/evidence/plains_redesign/final_current/'+report['stored']
for m in [report,metrics]:assert hashlib.sha256((E/m['stored']).read_bytes()).hexdigest()==m['stored_sha256']
note='''

## 透明度量与真实采样的因果边界

冻结规格失败仍是失败，不能事后放宽标准追认候选。但alpha>0包围盒/全高直沟槽可能受1/255尾部影响，alpha0像素的隐藏RGB在预览器可见不等于游戏中有灰底。实际校准中严格沟槽7px，alpha≥2为79px、alpha≥128为84px；这不构成降阈值批准，而是说明后续规格必须先用真实AtlasTexture region、filter_clip/导入、缩小比例及已知好坏例校准。没有实际GPU合屏，不得把源PNG/预览观测写成已证游戏halo、错缝或审美失败。原图、原冻结合同与blocked照旧保留；下一有界任务再建立采样正反例，不偷开本轮生成预算。

[实际独立校准及限定](../../../REPORT_PATH)。
'''.replace('REPORT_PATH',report_path)
for skill in ['art-director','scene-composer']:
    p=R/f'.agents/skills/{skill}/SKILL.md';s=p.read_text()
    assert '## 透明度量与真实采样的因果边界' not in s
    p.write_text(s+note)
p=R/'docs/quality/level_lessons.json';d=json.loads(p.read_text());lesson=next(x for x in d['lessons'] if x['id']=='asset-semantic-scale-and-preintegration-alpha')
limit='Independent C4 read-only calibration of the unchanged rejected PNG found alpha>=2 gutter79px and alpha>=128 gutter84px, with outer-edge alpha<=4/255. The original alpha>0 frozen contract still failed; no actual GPU halo/matte/seam is proven, and hidden RGB previews are not rendering evidence. Calibrate any future sampling rule against its real consumer before production, never retroactively pass this image.'
assert limit not in lesson['limits'];lesson['limits'].append(limit)
for original in ['build/plains_redesign/asset_contract_calibration/report.md','build/plains_redesign/asset_contract_calibration/metrics.json']:
    m=members[original];lesson['evidence'].append({'path':'docs/evidence/plains_redesign/final_current/'+m['stored'],'sha256':m['stored_sha256']})
movie_lesson=next(x for x in d['lessons'] if x['id']=='offline-movie-real-input-age')
movie_lesson['limits'].append('C4 original live-PNG outer movie failed7/1 at3007ticks; same-source headless matched states through3000 then tick3001 jump request lacked acceptance only in movie. One same-script no-live-PNG control later passed8/0 at6528ticks. This supports observer-condition association only: original trace lacks enqueue age/drop reason, TTL root cause remains UNKNOWN. Original failed capture stays failed; no Router timestamp/resource/physics or assertion changed. Post-extracted MP4 frame/time is not an exact native physical tick.')
for original in ['build/plains_redesign/final_regression_review/c4/outer_render_failure_review.md','build/plains_redesign/outer_no_live_png_movie/receipt.json','build/plains_redesign/final_outer_movie/receipt.json']:
    m=members[original];movie_lesson['evidence'].append({'path':'docs/evidence/plains_redesign/final_current/'+m['stored'],'sha256':m['stored_sha256']})
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print('Clarified existing source-backed lesson13 and two existing Skills; no threshold/candidate verdict/runtime change.')
