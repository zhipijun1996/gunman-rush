from pathlib import Path
import json
for name in ['PLAINS-REDESIGN-01','PLAINS-REDESIGN-GUI-LOCATOR-01']:
 p=Path('docs/quality/records')/(name+'.json');d=json.loads(p.read_text())
 for c in d['criteria']:
  assert 'reason' not in c
  c['reason']=c['status']+': '+c['scenario']+' '+c['method']
 p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print('Added required explanatory reason only; all original statuses, evidence and acceptance conditions unchanged.')
