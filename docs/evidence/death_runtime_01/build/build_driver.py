from pathlib import Path
import sys, os, subprocess, json, hashlib, time, re

commit = sys.argv[1]
assert len(commit) == 40 and all(c in '0123456789abcdef' for c in commit)
root = Path('/tmp/gunman-first-use-web-source')
out = Path('/tmp/death-runtime-web-build-evidence')
out.mkdir(exist_ok=False)
os.environ.update(GUNMAN_TOOLCHAIN_ROOT='/workspace/toolchains', PYTHONDONTWRITEBYTECODE='1', GIT_NO_LAZY_FETCH='1')

def command(argv, log, cap):
    start = time.monotonic()
    with (out/log).open('w') as stream:
        result = subprocess.run(argv, cwd=root, stdout=stream, stderr=subprocess.STDOUT, timeout=cap)
    row = {'argv':argv, 'exit':result.returncode, 'seconds':time.monotonic()-start, 'budget':cap, 'log':log}
    with (out/'commands.jsonl').open('a') as stream: stream.write(json.dumps(row)+'\n')
    print(json.dumps(row), flush=True)
    assert result.returncode == 0, row
    assert not re.search(r'SCRIPT ERROR:|SHADER ERROR:|(?m:^ERROR:)|ObjectDB.*leaked|resources? still in use at exit', (out/log).read_text()), row

def sha(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest()

# Preserve the previous exact downloadable PCK without allocating another copy.
previous = root/'build/web/index.9dd3a9a2ecd8.pck'
assert sha(previous) == '9dd3a9a2ecd845d5728089693282e1642ab1efa2e1868e3925c637fbaa32e0e5'
backup = Path('/tmp/death-runtime-01/baseline/index.9dd3a9a2ecd8.pck')
if not backup.exists(): os.link(previous,backup)
assert sha(backup) == sha(previous)
(out/'previous-pack-preserved.json').write_text(json.dumps({'old_path':str(previous),'preserved_path':str(backup),'sha256':sha(backup),'bytes':backup.stat().st_size},indent=2)+'\n')

changes = subprocess.check_output(['git','diff','--name-only'],cwd=root,text=True).splitlines()
allowed = set(json.loads(Path('/workspace/refactor-evidence/death-runtime-01/production-application.json').read_text())[i]['path'] for i in range(8))
assert all(name in allowed or name.startswith('resources/foundry/') for name in changes), changes
assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=root).strip()
old_generated = {str(p.relative_to(root)): {'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted((root/'resources/foundry').rglob('*')) if p.is_file()}
(out/'previous-generated.json').write_text(json.dumps(old_generated,indent=2)+'\n')
command(['git','restore','--source=HEAD','--worktree','--',*sorted(allowed),'resources/foundry'],'restore-temp-candidates.log',30)
command(['git','checkout','--detach',commit],'checkout.log',60)

sys.path.insert(0,str(root/'tools'))
from verify_ci_artifact_browser import SourceRoot, tree, file_identity
from harness import source_files
before = SourceRoot(root,commit).snapshot()
(out/'clean-source-before.json').write_text(json.dumps(before,sort_keys=True))

# Original export-integrity prerequisite, with original per-engine budgets.
command(['python3','tools/foundry.py','build','--count','24','--promote'],'foundry.log',1050)
command(['python3','tools/build.py','web'],'build.log',500)
command(['python3','tools/check_web_bundle.py','build/web'],'web-closure.log',120)
command(['python3','tools/style_exploration_delivery.py','reconstruct-pack','--bundle','build/web','--output',str(out/'pack-proof.json')],'reconstruction.log',120)

derived = {str(p.relative_to(root)):sha(p) for p in sorted((root/'resources/foundry').rglob('*')) if p.is_file()}
entries = tree(root,commit)
assert set(source_files(root)) == set(entries) | set(derived)
after = {}
for name, entry in entries.items():
    if name in derived:
        value = sha(root/name)
        assert value == derived[name]
    else:
        value = file_identity(root/name,entry[1],'sha1',entry[0])
        assert value == before['source_sha256'][name], name
    after[name] = value
from check_web_bundle import Pack
info = json.loads((root/'build/web/build-info.json').read_text())
assert info['source_commit'] == commit
pack = Pack(root/'build/web'/info['pack'])
for name, expected in derived.items(): assert hashlib.sha256(pack.read(name)).hexdigest() == expected,name
(out/'generated-inputs.json').write_text(json.dumps({'producer':'original foundry.py build --count24 --promote + original export stamp','derived_sha256':derived,'count':len(derived)},sort_keys=True))
(out/'build-after.json').write_text(json.dumps({'status':'source_plus_explicit_newly_validated_foundry_inputs','source_commit':commit,'actual_sha256':after,'derived_sha256':derived,'build_info':info},sort_keys=True))
print(json.dumps({'status':'PASS','build_info':info,'evidence':str(out)}),flush=True)
