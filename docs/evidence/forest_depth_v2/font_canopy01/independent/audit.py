from pathlib import Path
from hashlib import sha256
import json,re
from collections import Counter
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import DecomposingRecordingPen
R=Path(__file__).resolve().parents[5]
O=Path(__file__).resolve().parent
old=R/'build/forest_depth/root/font-canopy-fix01/before.ttf'
new=R/'assets/fonts/windkeeper_ui.ttf'
paths=[old,new,R/'tools/subset_plains_ui_font.py',R/'scripts/bosses/thorn_queen_canopy_encounter.gd',R/'resources/bosses/thorn_queen_canopy.tres',R/'assets/fonts/OFL.txt',R/'assets/fonts/README.md']
def digest(p):return sha256(p.read_bytes()).hexdigest()
before={str(p.relative_to(R)):digest(p) for p in paths}
a,b=TTFont(old),TTFont(new)
ca,cb=a.getBestCmap(),b.getBestCmap()
def outline(f,g):
 gs=f.getGlyphSet();p=DecomposingRecordingPen(gs);gs[g].draw(p);return p.value
missing=sorted(set(ca)-set(cb)); mapping=[hex(c) for c in ca if c in cb and ca[c]!=cb[c]]
outline_diff=[hex(c) for c in ca if c in cb and outline(a,ca[c])!=outline(b,cb[c])]
metrics={}
for t in ('hmtx','vmtx'):
 if t in a:
  metrics[t]=[hex(c) for c in ca if c in cb and a[t].metrics[ca[c]]!=b[t].metrics[cb[c]]]
fields={'head':['unitsPerEm'],'hhea':['ascent','descent','lineGap','advanceWidthMax','minLeftSideBearing','minRightSideBearing','xMaxExtent','caretSlopeRise','caretSlopeRun','caretOffset'],'vhea':['ascent','descent','lineGap','advanceHeightMax','minTopSideBearing','minBottomSideBearing','yMaxExtent','caretSlopeRise','caretSlopeRun','caretOffset'],'OS/2':['sTypoAscender','sTypoDescender','sTypoLineGap','usWinAscent','usWinDescent','sxHeight','sCapHeight','usWeightClass','usWidthClass'],'post':['italicAngle','underlinePosition','underlineThickness','isFixedPitch']}
global_diff=[]
for table,attrs in fields.items():
 if table not in a:continue
 for attr in attrs:
  if hasattr(a[table],attr) and getattr(a[table],attr)!=getattr(b[table],attr):global_diff.append([table,attr,getattr(a[table],attr),getattr(b[table],attr)])
enc=paths[3].read_text(); obj=enc.split('func objective() -> String:',1)[1].split('\nfunc ',1)[0]
literals=re.findall(r'"([^"\n]*)"',obj)+re.findall(r'^display_name\s*=\s*"([^"\n]*)"',paths[4].read_text(),re.M)
coverage=[{'text':s,'missing':''.join(sorted(set(c for c in s if ord(c) not in cb)))} for s in literals]
# Additionally audit every non-ASCII literal/source character consumed by the tool's Boss glob.
boss_coverage={}
for p in sorted(list((R/'scripts/bosses').glob('*.gd'))+list((R/'resources/bosses').glob('*.tres'))):
 absent=''.join(sorted(set(c for c in p.read_text() if ord(c)>=128 and ord(c) not in cb)))
 if absent:boss_coverage[str(p.relative_to(R))]=absent
unmapped_old_glyphs=[g for g in a.getGlyphOrder() if g not in ca.values()]
def glyph_signature(f,g):
 return repr((outline(f,g),f['hmtx'].metrics[g], f['vmtx'].metrics[g] if 'vmtx' in f else None))
# fontTools assigns anonymous glyphNNNN names by subset index; adding a glyph can renumber them.
# Compare all old glyph shapes/metrics as a multiset instead of treating those generated names as identities.
old_signatures=Counter(glyph_signature(a,g) for g in a.getGlyphOrder())
new_signatures=Counter(glyph_signature(b,g) for g in b.getGlyphOrder())
unmapped_diffs=list((old_signatures-new_signatures).elements())
a.close();b.close()
after={str(p.relative_to(R)):digest(p) for p in paths}
res={'scope':'Read-only font data delta; no native execution, pixel/device/player or release acceptance. Reviewer did not implement font rebuild.','sources':before,'source_stable':before==after,'old_codepoints':len(ca),'new_codepoints':len(cb),'added':[{'codepoint':f'U+{c:04X}','character':chr(c)} for c in sorted(set(cb)-set(ca))],'missing_old_codepoints':missing,'changed_cmap_names':mapping,'changed_decomposed_outlines':outline_diff,'changed_metrics':metrics,'changed_global_metrics':global_diff,'unmapped_old_glyphs':unmapped_old_glyphs,'unmapped_old_glyph_differences':unmapped_diffs,'actual_canopy_objective_and_name':coverage,'all_boss_glob_missing_nonascii':boss_coverage,'new_font_nlink':new.stat().st_nlink}
res['status']='ACCEPT' if before==after and not any([missing,mapping,outline_diff,global_diff,unmapped_diffs,boss_coverage,*metrics.values()]) and not any(x['missing'] for x in coverage) and set(cb)-set(ca)=={ord('岸')} else 'REJECT'
(O/'audit.json').write_text(json.dumps(res,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(res,ensure_ascii=False,indent=2))
