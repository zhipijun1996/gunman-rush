"""Original explicit palette-index art; no source-image editing or resampling.
Rows below are the authored pixels, centered in the declared 36x48 grid.
"""
from pathlib import Path
from PIL import Image
import json, hashlib
p=Path(__file__).resolve().parent
palette={'.':(0,0,0,0),'K':(8,10,16,255),'D':(30,22,16,255),'B':(89,54,23,255),'T':(116,86,49,255),'L':(171,142,86,255),'M':(61,78,51,255),'m':(105,123,75,255),'C':(144,109,48,255),'c':(203,164,82,255),'E':(236,201,137,255),'G':(244,171,71,255),'S':(61,46,31,255)}
raw=['', 'KK...KK', 'KmmK.KMK', 'KmLTBBMMK', 'KMLTTBBBDKK', 'KMLTCccccCBK', 'KLTBcEccEcCBK', 'KTBBcKKcKcCBK', 'KDBBCcKcKcCBK', 'KTBBCccccCCDK', 'KmBTBCccCDBK', 'KKmMLTTBBDKKK', 'KKmMLTTBBDKTBmKKK', 'KmmMLTTTTBBDKTBBTMmmKK', 'KMLLTTBTBTBBDKBTBBTTMmMK', 'KMLTBTBBTBTTBDKBTBBTTBBMmK', 'KLTBDBBKBTBBBDKBBBTTBBBKBBK', 'KLTBDBKKBTBLLTBBTTBBBK.KBBTK', 'KLTBDBK.KBTLCCCCCCTBK.KDBBTK', 'KLTBBK..KBTLCGEEGCLBK..KDBBTK', 'KBTBDK..KBTLCGEEGCLBK..KDBBTK', 'KBTBDK..KBTLCEGGCLTBK..KDBBTK', 'KLTBDK..KBTBLCCCLTTBK..KDBBTK', 'KLTBDK..KBTBBTBBTTBBK..KDBBTK', 'KLTBDK..KBTBBKBBTTBDK..KDBBBK', 'KLTBDK..KBTBBKBBTBBDK..KDBBBK', 'KBTBDK..KBTBBKBBTBBDK..KDBTK', 'KBTBDK..KDBBBKBBTBBDK..KDBTK', 'KBTBBK..KDBTTKBBTBBDK..KBBK', 'KBBKBK..KDBTTKBBTBBDK..KKK', 'KBBKKK..KDBBBKBBTBBDK', 'KKK....KDBTBBKKBTBDK', 'KDBTTBK.KBTBDK', 'KDBTTBK.KBTBDK', 'KDBTBK..KBTBDK', 'KDBTBK...KBTBDK', 'KDBTBK...KBTBDK', 'KDBTBK....KBTBDK', 'KDBTTBK....KBTBDK', 'KDBTTBK.....KBTBDK', 'KMLTBTBK.....KBTBDK', 'KmLTBTBDK.....KBTBDK', 'KMLTBTBDKK.....KBTBTBK', 'KmLTBBBDKDK....KBTBTMmK', 'KMLTBBDKKDDK...KDBTBTMmK', 'KmLTBBDKKKDDK...KDKDBBTBTMmK', 'KKKKKKK..KKKKK...KKKK.KKKKKKK', '']
assert len(raw)==48,len(raw)
assert max(map(len,raw))<=36
rows=[r.center(36,'.') for r in raw]
assert all(len(r)==36 for r in rows)
(p/'guardian-authored.rows').write_text('\n'.join(rows)+'\n')
(p/'guardian.palette.json').write_text(json.dumps({'palette':palette,'note':'K,D,B,E inherited from actual shared actor RGB; all other sparse wood/bronze/moss ramps authored regional swatches. No full-palette equality claim.'},indent=2)+'\n')
im=Image.new('RGBA',(36,48));im.putdata([palette[c] for r in rows for c in r]);im.save(p/'guardian.native.png')
print('Authored',im.size,'bbox',im.getbbox(),'SHA',hashlib.sha256((p/'guardian.native.png').read_bytes()).hexdigest())
