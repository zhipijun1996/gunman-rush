"""Ignored prepared runner support. Importing this does not run any native consumer."""
from pathlib import Path
import hashlib,json,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[3]
def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb') as s:
  while b:=s.read(1024*1024):h.update(b)
 return h.hexdigest()
def write(p,x):Path(p).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
def state(expected):
 if not re.fullmatch('[0-9a-f]{40}',expected):raise ValueError('Explicit full final main M SHA required; no HEAD alias/historical default')
 head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 status=subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True)
 if head!=expected or status:raise ValueError('Require exact expected final main M and clean source')
 sys.path.insert(0,str(ROOT/'tools'))
 from run_forest_depth_region import inventory
 return {'head':head,'git_status':status,'inventory':inventory()}
def fresh(path):
 path=Path(path).resolve()
 if not path.is_relative_to(ROOT/'build') or path.exists():raise ValueError('New ignored output below repository build required; never overwrite old evidence')
 path.mkdir(parents=True);return path
def bound(path,expected):
 rel=str(Path(path).resolve().relative_to(ROOT));data=subprocess.check_output(['git','show',expected+':'+rel],cwd=ROOT)
 actual=sha(ROOT/rel)
 if actual!=hashlib.sha256(data).hexdigest():raise ValueError('Executing source differs from exact M: '+rel)
 return {'path':rel,'sha256':actual}
