"""Original explicit palette-index pixels; no editing/resizing a source image."""
from pathlib import Path
from PIL import Image
import json,hashlib
p=Path(__file__).resolve().parent
palette={'.':(0,0,0,0),'K':(8,10,16,255),'D':(30,22,16,255),'B':(89,54,23,255),'T':(116,86,49,255),'L':(171,142,86,255),'M':(61,78,51,255),'m':(105,123,75,255),'C':(144,109,48,255),'c':(203,164,82,255),'E':(236,201,137,255),'G':(244,171,71,255),'S':(61,46,31,255)}
raw=[
'',
'....T..........................T',
'....TK........................KT',
'.T...TBK....................KBT...T',
'.TK...TBK......T.....T.....KBT...KT',
'..TBK..TBK.....TK...KT....KBT..KBT',
'...TBK..TBK....TBK.KBT...KBT..KBT',
'....TBK.KTBK....TBKBT...KBTK.KBT',
'.....TBK.KTBK....TKBT..KBTK.KBT',
'......TBK.KTBK...TBKT.KBTK.KBT',
'.......TBK.KTBK..TKBTKBTK.KBT',
'........TBK.KTBK.KTBTBTK.KBT',
'.........TBK.KTBBccccBBK.KBT',
'..........TBKKTBcEEccCBKBT',
'...........TBLTBcKcKcCBLT',
'...........KTBBCccKccCBTK',
'...........KTBBCcccccCBTK',
'..........KTBK.KBCccBK.KBTK',
'.........KTBK..KBTBTBK..KBTK',
'........KTBK...KBLTBK...KBTK',
'.......KTBK....KBLTBK....KBTK',
'.......KTBK....KBTBTK....KBTK',
'.......KBTBK...KBTBTK...KBTBK',
'........KBTBK..KBTBTK..KBTBK',
'.........KBBK.KBTBTBTK.KBBK',
'..........KK.KBTBKBTBK.KK',
'............KBTBK.KBTBK',
'...........KBTBK...KBTBK',
'..........KBTBK.....KBTBK',
'.........KBTBK.......KBTBK',
'........KBTBK...TK....KBTBK',
'.......KBTBK...KBTK....KBTBK',
'......KKKKK...KKKKK....KKKKK',
''
]
assert len(raw)==34,len(raw)
assert max(map(len,raw))<=36,max(map(len,raw))
rows=[r.ljust(36,'.') for r in raw]
(p/'queen-authored.rows').write_text('\n'.join(rows)+'\n');(p/'queen.palette.json').write_text(json.dumps({'palette':palette,'note':'Four shared actor RGB references plus explicitly authored sparse wood/bronze/moss/resin ramp; no silver silk knots or white thorn danger cues baked.'},indent=2)+'\n')
im=Image.new('RGBA',(36,34));im.putdata([palette[c] for row in rows for c in row]);im.save(p/'queen.native.png')
print(im.size,im.getbbox(),hashlib.sha256((p/'queen.native.png').read_bytes()).hexdigest())
