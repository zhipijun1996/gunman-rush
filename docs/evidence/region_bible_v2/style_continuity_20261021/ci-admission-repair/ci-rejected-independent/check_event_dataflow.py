from pathlib import Path
import copy,hashlib,json,re,sys,yaml
BASE=Path(__file__).resolve().parent
class Expr:
 def __init__(self,s,ctx):
  self.ctx=ctx;self.t=[];self.i=0
  pat=re.compile(r"\s*('(?:[^']|'')*'|&&|\|\||==|[(),]|[A-Za-z_][A-Za-z0-9_.]*)")
  pos=0
  while pos<len(s):
   if not s[pos:].strip():break
   m=pat.match(s,pos)
   if not m:raise ValueError(('Unsupported expression',s[pos:]))
   self.t.append(m[1]);pos=m.end()
 def take(self):v=self.t[self.i];self.i+=1;return v
 def peek(self):return self.t[self.i] if self.i<len(self.t) else None
 def atom(self):
  t=self.take()
  if t=='(':
   v=self.expr();assert self.take()==')';return v
  if t.startswith("'"):return t[1:-1].replace("''", "'")
  if self.peek()=='(':
   self.take();a=[]
   while self.peek()!=')':
    a.append(self.expr())
    if self.peek()!=',':break
    self.take()
   assert self.take()==')'
   if t=='contains':return str(a[1]).casefold() in str(a[0]).casefold()
   if t=='format':return str(a[0]).format(*a[1:])
   raise ValueError(('Unknown function',t))
  if t in ['true','false','null']:return {'true':True,'false':False,'null':None}[t]
  v=self.ctx
  for part in t.split('.'):v=v.get(part,'') if isinstance(v,dict) else ''
  return v
 def expr(self,minimum=0):
  lhs=self.atom();prec={'||':1,'&&':2,'==':3}
  while self.peek() in prec and prec[self.peek()]>=minimum:
   op=self.take();rhs=self.expr(prec[op]+1)
   if op=='||':lhs=lhs if lhs else rhs
   elif op=='&&':lhs=rhs if lhs else lhs
   else:lhs=lhs.casefold()==rhs.casefold() if isinstance(lhs,str) and isinstance(rhs,str) else lhs==rhs
  return lhs
 def value(self):v=self.expr();assert self.i==len(self.t);return v

def evaluate(s,ctx):return Expr(s,ctx).value()
def template(s,ctx):return re.sub(r'\$\{\{(.*?)\}\}',lambda m:str(evaluate(m[1],ctx)),s).casefold()
def context(event='push',ref='refs/heads/topic',repo='owner/game',head_repo=None,head_ref=None,message='',manual_publish=False):
 d={'github':{'workflow':'Godot core','repository':repo,'event_name':event,'ref':ref,'ref_name':ref.removeprefix('refs/heads/').removeprefix('refs/tags/'),'sha':'b'*40,'event':{'head_commit':{'message':message}}},'inputs':{'deploy_playtest':manual_publish,'build_android':False}}
 if event=='pull_request':d['github']['event']['pull_request']={'head':{'sha':'a'*40,'ref':head_ref or 'topic','repo':{'full_name':head_repo or repo}}}
 return d

def inspect(path):
 new=yaml.load(path.read_text(),Loader=yaml.BaseLoader);old=yaml.load((BASE/'baseline-environment.yml').read_text(),Loader=yaml.BaseLoader)
 group=new['concurrency']['group'];oldgroup=old['concurrency']['group'];gate=new['jobs']['deploy_web']['if'];rows=[]
 contexts={'push_topic':context(),'PR_topic':context('pull_request','refs/pull/96/merge'), 'fork_PR_topic':context('pull_request','refs/pull/97/merge',head_repo='fork/game'),'manual_topic':context('workflow_dispatch',manual_publish=True),'push_other':context(ref='refs/heads/other'),'push_main':context(ref='refs/heads/main'),'tag_main':context(ref='refs/tags/main'),'publish_feature_push':context(ref='refs/heads/feature/complete-actor-actions',message='ready [publish-playtest]'),'publish_feature_PR':context('pull_request','refs/pull/98/merge',head_ref='feature/complete-actor-actions'),'manual_main':context('workflow_dispatch','refs/heads/main',manual_publish=True)}
 for name,ctx in contexts.items():
  rows.append({'case':name,'group':template(group,ctx),'baseline_group':template(oldgroup,ctx),'checkout_expected':ctx['github']['event'].get('pull_request',{}).get('head',{}).get('sha',ctx['github']['sha']),'publish_eligible':bool(evaluate(gate,ctx))})
 by={x['case']:x for x in rows};checks={}
 checks['ordinary_push_PR_dedup']=by['push_topic']['group']==by['PR_topic']['group']
 checks['fork_isolated']=by['push_topic']['group']!=by['fork_PR_topic']['group']
 checks['manual_publish_isolated']=by['manual_topic']['group']!=by['push_topic']['group']
 checks['other_branch_isolated']=by['push_other']['group']!=by['push_topic']['group']
 checks['tag_main_must_not_cancel_branch_main']=by['tag_main']['group']!=by['push_main']['group']
 checks['auto_publish_feature_must_not_be_cancelled_by_ineligible_PR']=by['publish_feature_push']['group']!=by['publish_feature_PR']['group']
 jobs=[]
 for name,job in new['jobs'].items():
  for step in job.get('steps',[]):
   if str(step.get('uses','')).startswith('actions/checkout@'):
    jobs.append(name);expr=step['with']['ref']
    for case,ctx in contexts.items():
     actual=re.sub(r'\$\{\{(.*?)\}\}',lambda m:str(evaluate(m[1],ctx)),expr)
     assert actual==by[case]['checkout_expected'],(name,case,actual)
 checks['all_seven_checkouts_exact_head_or_event_sha']=len(jobs)==7
 prepare=[x for x in new['jobs']['prepare']['steps'] if x.get('name')=='Check committed quality evidence before toolchain work'][0]
 checks['evidence_checks_actual_git_HEAD']=prepare['run']=='python3 tools/check_release_evidence.py --commit "$(git rev-parse HEAD)"'
 norm=copy.deepcopy(new);norm['concurrency']['group']=old['concurrency']['group']
 for name,job in norm['jobs'].items():
  for i,step in enumerate(job.get('steps',[])):
   if str(step.get('uses','')).startswith('actions/checkout@'):
    step['with'].pop('ref');
    if not step['with']:step.pop('with')
   if name=='prepare' and step.get('name')=='Check committed quality evidence before toolchain work':step['run']=old['jobs'][name]['steps'][i]['run']
 checks['all_other_workflow_guards_budgets_lanes_publish_permissions_unchanged']=norm==old
 return {'scope':'Independent actual-YAML finite GitHub-expression evaluation; no GitHub run or scheduler execution','workflow':str(path),'workflow_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'expression_subset':'Missing context empty; truthy &&/||; case-insensitive string== and concurrency key; contains/format; no network or production-test imports','checkout_jobs':jobs,'cases':rows,'checks':checks,'failed_required_controls':[k for k,v in checks.items() if not v]}
if __name__=='__main__':
 p=Path(sys.argv[1]) if len(sys.argv)>1 else BASE/'reviewed-environment.yml';print(json.dumps(inspect(p),ensure_ascii=False,indent=2))
