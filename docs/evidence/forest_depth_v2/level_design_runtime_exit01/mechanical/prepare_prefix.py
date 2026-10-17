from pathlib import Path
import json
R=Path('/workspace/gunman-rush-design');S=R/'build/forest_depth/snapshots/level_capability01';O=S/'build/capability_boundary';s=(O/'case.gd').read_text()
ends=[('\tvar build =','player'),('\tvar baseline =','build'),('\tvar driver =','snapshot'),('\tverify(actor.traversal.grant','trace')]
for end,label in ends:
 text=s[:s.index(end)]+'\tmotor.free()\n\tawait get_tree().process_frame\n\tprint("PREFIX '+label+': ",assertions," / ",failures)\n'
 (O/(label+'_case.gd')).write_text(text)
 entry=(O/'entry.gd').read_text().replace('case.gd',label+'_case.gd').replace('case.failures!=0 or case.assertions!=41','case.failures!=0')
 (O/(label+'_entry.gd')).write_text(entry)
