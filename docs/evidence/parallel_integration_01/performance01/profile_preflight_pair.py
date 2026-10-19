"""Read-only paired measurement; no worker, engine, or mocked input reads."""
import ast
import cProfile
import hashlib
import json
from pathlib import Path, PurePosixPath, PureWindowsPath
import pstats
import subprocess
import sys
import time
sys.path.insert(0, str(Path.cwd()/'tools'))
import production_loop as loop

out=Path('build/integration01/production-loop-performance')
out.mkdir(exist_ok=True)
baseline=subprocess.check_output(['git','show','HEAD:tools/production_loop.py'],text=True)
node=next(n for n in ast.parse(baseline).body if isinstance(n,ast.FunctionDef) and n.name=='required_input_preflight')
namespace=dict(vars(loop))
exec(compile(ast.Module(body=[node],type_ignores=[]),'<baseline-preflight>','exec'),namespace)
task={'id':'DRILL','goal':'inspect','skills':['gameplay-reviewer'],'read_only':True,'checks':['docs']}
results={}
for label,fn in [('before',namespace['required_input_preflight']),('after',loop.required_input_preflight)]:
    prof=cProfile.Profile();start=time.perf_counter();prof.enable();data=fn(task);prof.disable()
    elapsed=time.perf_counter()-start;prof.dump_stats(str(out/f'{label}.prof'))
    with (out/f'{label}.txt').open('w') as log:
        pstats.Stats(prof,stream=log).strip_dirs().sort_stats('cumulative').print_stats(25)
    results[label]={'profiled_seconds':elapsed,'status':data['status'],'result_sha256':hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()}
    if label=='before':expected=data
    else:assert data==expected

# Exact old/new lexical algebra, including invalid/outside candidates. The
# Windows production branch deliberately remains the original pathlib rule.
checks=[]
for cls,root in [(PurePosixPath,'/repo'),(PurePosixPath,'/'),(PureWindowsPath,'C:/Repo')]:
    root=cls(root);parts=root.parts
    for name in ['.', '', 'docs/proof', '../repo-other/proof', '../escape',
                 'docs/../proof','docs/../../escape','/outside','/repo-other',
                 '/repo','/repo/proof','C:/repo/proof','D:/Repo/proof']:
        path=root/name
        old=tuple(p for p in [path,*path.parents] if p==root or p.is_relative_to(root))
        new=old if cls==PureWindowsPath else tuple(p for p in [path,*path.parents] if p.parts[:len(parts)]==parts)
        assert old==new,(root,name,old,new)
        checks.append({'flavour':cls.__name__,'root':str(root),'name':name})
    for candidate in [root,root/'proof',root/'docs/../proof',cls(str(root)+'-other')/'proof',cls('/outside')]:
        old=candidate.relative_to(root).as_posix() if candidate.is_relative_to(root) else None
        new=old if cls==PureWindowsPath else ('/'.join(candidate.parts[len(parts):]) or '.') if candidate.parts[:len(parts)]==parts else None
        assert old==new,(root,candidate,old,new)

results.update(lexical_cases=len(checks),exact_result_equal=True,filesystem_state_cached=False,
    production_file_sha256=hashlib.sha256(Path('tools/production_loop.py').read_bytes()).hexdigest(),
    limitations='Profile timings include instrumentation; Windows unchanged branch algebra only, not Windows execution.')
(out/'paired.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results,indent=2))
