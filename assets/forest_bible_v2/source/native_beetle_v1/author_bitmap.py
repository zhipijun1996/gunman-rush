"""Original explicit palette-index pixels; no editing/resizing a source image."""
from pathlib import Path
from PIL import Image
import json,hashlib
p=Path(__file__).resolve().parent
palette={'.':(0,0,0,0),'K':(8,10,16,255),'D':(30,22,16,255),'B':(89,54,23,255),'T':(116,86,49,255),'L':(171,142,86,255),'M':(61,78,51,255),'m':(105,123,75,255),'C':(144,109,48,255),'c':(203,164,82,255),'E':(236,201,137,255),'G':(244,171,71,255),'S':(61,46,31,255)}
raw=['', '.......mmMM', '.....KMmMLmMKK', '....KMmLTTBBBMK', '...KMLTTBTBTBBMK', '..KMLTBBTBTBTBBMK..K', '..KMLBTBDTBBBTBBK.KTK', '..KmLTBBDTBBTBTBKKTLK', '..KmLTTBDTBTTBTBKTEBK', '...KMLTBBTTBBBTBKKTBK', '...KBBTBBBTBBTBDK.BK', '....KDBBBTBBBDKK.KBK', '....KLTK.KLTK.KLTK.KK', '...KLTK..KLTK..KLTK', '..KmmK..KmmMK..KmmK', '']
assert len(raw)==16 and max(map(len,raw))<=24
rows=[r.ljust(24,'.') for r in raw];(p/'beetle-authored.rows').write_text('\n'.join(rows)+'\n');(p/'beetle.palette.json').write_text(json.dumps({'palette':palette,'note':'Four shared actor RGB references plus authored sparse forest bark/bronze/moss ramp. Right-facing thick wood head; pale upper-left moss on vulnerable rear. Short offset grain and light roots avoid repeated black bars. No silver silk sac.'},indent=2)+'\n')
im=Image.new('RGBA',(24,16));im.putdata([palette[c] for row in rows for c in row]);im.save(p/'beetle.native.png')
print(im.size,im.getbbox(),hashlib.sha256((p/'beetle.native.png').read_bytes()).hexdigest())
