"""Independent executable negative cases, isolated temporary git consumers."""
import subprocess, tempfile, types, argparse, json
from pathlib import Path
from unittest.mock import patch
p=argparse.ArgumentParser();p.add_argument("--source",required=True);args=p.parse_args()
code=subprocess.check_output(["git","show",args.source+":tools/harness.py"],text=True)
h=types.ModuleType("review_harness");h.__file__=str(Path("tools/harness.py").resolve());exec(compile(code,h.__file__,"exec"),h.__dict__)
results=[]
for label,mutation in [("new_untracked", "Path('unexpected.gd').write_text('changed source')"),("tracked_deleted", "Path('input.txt').unlink()"),("tracked_modified", "Path('input.txt').write_text('changed')")]:
 with tempfile.TemporaryDirectory() as d:
  root=Path(d)/"repo";root.mkdir()
  def git(*argv):return subprocess.run(["git",*argv],cwd=root,check=True,capture_output=True)
  git("init","-q");git("config","user.email","review@example.invalid");git("config","user.name","Independent reviewer")
  (root/".gitignore").write_text("build/\n");(root/"input.txt").write_text("original");git("add",".");git("commit","-qm","fixture")
  folder=root/"build/report";folder.mkdir(parents=True)
  check={"argv":["python3","-c","from pathlib import Path; "+mutation+"; print('COMPLETE')"],"timeout_seconds":5,"success_pattern":"^COMPLETE$"}
  with patch.object(h,"ROOT",root),patch.object(h,"toolchain_identity",return_value={}):
   actual=h.execute_checks({"checks":{"mutation":check}},["mutation"],folder,jobs=2)[0]
  results.append({"case":label,"source":args.source,"status":actual["status"],"reason":actual.get("reason"),"host_unchanged":(root/"input.txt").read_text()=="original" and not (root/"unexpected.gd").exists()})
print(json.dumps(results,indent=2))
