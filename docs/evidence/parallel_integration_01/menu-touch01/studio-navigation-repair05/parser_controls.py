import copy,csv,hashlib,io,json,sys
from pathlib import Path
ROOT=Path('/workspace/gunman-rush-design');sys.path.insert(0,str(ROOT/'tools'))
import studio_gui_pointer as helper
out=Path(__file__).resolve().parent
source=ROOT/'build/studio-navigation/1792410362360088566/title-4.tsv'
rows=list(csv.DictReader(io.StringIO(source.read_text()),delimiter='\t'));fields=rows[0].keys();label='DEVELOPMENT DEMOS / ALL ENTRIES'
def encode(items):
 f=io.StringIO();w=csv.DictWriter(f,fieldnames=fields,delimiter='\t');w.writeheader();w.writerows(items);return f.getvalue()
assert helper._studio_label_box(source.read_text(),label,3)==((669+1190)/6,(787+17/2)/3)
normal=copy.deepcopy(rows)
for w in normal:
 if w['text']in ['DEVELOPMENT','DEMOS','ALL','ENTRIES']:w['block_num']='99';w['par_num']='1';w['line_num']='1'
assert helper._studio_label_box(encode(normal),label,3)==((669+1190)/6,(787+17/2)/3)
results=[]
for case in ['cross_baseline','large_gap','partial','wrong_suffix','duplicate_complete','cross_parser_duplicate']:
 changed=copy.deepcopy(rows)
 if case=='cross_baseline':
  for w in changed:
   if w['text']in ['ALL','ENTRIES']:w['top']=str(int(w['top'])+1)
 elif case=='large_gap':
  for w in changed:
   if w['text']in ['ALL','ENTRIES']:w['left']=str(int(w['left'])+100)
 elif case=='partial':changed=[w for w in changed if w['text']!='ENTRIES']
 elif case=='wrong_suffix':
  for w in changed:
   if w['text']=='ENTRIES':w['text']='ENTRIES2'
 elif case=='cross_parser_duplicate':changed=list(csv.DictReader(io.StringIO((out/'cross-path-duplicate.tsv').read_text()),delimiter='\t'))
 else:
  for w in rows:
   if w['text']in ['DEVELOPMENT','DEMOS','ALL','ENTRIES']:
    w=copy.deepcopy(w);w['top']=str(int(w['top'])+300);w['block_num']=str(int(w['block_num'])+100);changed.append(w)
 try:helper._studio_label_box(encode(changed),label,3);raise RuntimeError('Accepted '+case)
 except AssertionError as e:results.append({'case':case,'rejected':True,'error':str(e)})
report={'status':'passed_scoped_parser_controls','scope':'Actual TSV parser controls, not live GUI approval','helper_sha256':hashlib.sha256((ROOT/'tools/studio_gui_pointer.py').read_bytes()).hexdigest(),'actual_split_block_positive':True,'normal_row_and_same_bbox_both_paths_positive':True,'negative_controls':results,'prior_reject_preserved':'reject04.json'}
(out/'audit.json').write_text(json.dumps(report,indent=2)+'\n');print('PASS split and normal/same-bbox positives;6 negatives including cross-parser duplicate refused')
