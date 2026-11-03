from pathlib import Path
import subprocess,tempfile,hashlib,json,time,os
out=Path(__file__).resolve().parent
fixture=Path(tempfile.mkdtemp(prefix="gunman-promisor-independent-",dir="/tmp"))
seed_repo=fixture/"seed";remote_repo=fixture/"remote.git";clone_repo=fixture/"clone"
commands=[]
def run(c,cwd=None,limit=15):
 start=time.monotonic();p=subprocess.run(c,cwd=cwd,capture_output=True,timeout=limit)
 r={"argv":c,"cwd":str(cwd) if cwd else None,"exit_code":p.returncode,"seconds":time.monotonic()-start,"stdout":p.stdout.decode(errors="replace"),"stderr":p.stderr.decode(errors="replace")};commands.append(r);return p

def ok(c,cwd=None):
 r=run(c,cwd);assert r.returncode==0,commands[-1];return r.stdout
seed_repo.mkdir();ok(["git","init","-b","main"],seed_repo)
ok(["git","config","user.name","isolated-ci-fixture"],seed_repo);ok(["git","config","user.email","fixture@example.invalid"],seed_repo)
(seed_repo/"README.md").write_text("isolated promisor fixture; not game source\n")
name="docs/evidence/held/data.bin";payload=bytes(range(256))*8192
source=seed_repo/name;source.parent.mkdir(parents=True);source.write_bytes(payload)
ok(["git","add","."],seed_repo);ok(["git","commit","-m","fixture"],seed_repo)
oid=ok(["git","rev-parse","HEAD:"+name],seed_repo).decode().strip()
ok(["git","clone","--bare",str(seed_repo),str(remote_repo)])
ok(["git","config","uploadpack.allowFilter","true"],remote_repo);ok(["git","config","uploadpack.allowAnySHA1InWant","true"],remote_repo)
ok(["git","clone","--filter=blob:none","--no-local","--no-checkout",remote_repo.as_uri(),str(clone_repo)])
ok(["git","sparse-checkout","set","--no-cone","/*","!/docs/evidence/"],clone_repo)
ok(["git","checkout","main"],clone_repo)
head=ok(["git","rev-parse","HEAD"],clone_repo).decode().strip()
index=ok(["git","ls-files","--stage"],clone_repo)
assert not (clone_repo/name).exists()
missing=run(["git","--no-lazy-fetch","cat-file","-e",oid],clone_repo);assert missing.returncode!=0
held=clone_repo/name;held.parent.mkdir(parents=True);held.write_bytes(payload);held.chmod(0o644)
assert hashlib.sha1(b"blob "+str(len(payload)).encode()+b"\0"+payload).hexdigest()==oid
assert (clone_repo/".git/objects/pack").is_dir() and list((clone_repo/".git/objects/pack").glob("*.promisor"))
remote_repo.rename(fixture/"remote-offline.git")
before=run(["git","diff","--name-only","-z","HEAD"],clone_repo)
# No other mutation occurs between the failing diff and this documented cache hydrate.
hydrate=run(["git","hash-object","-w","--no-filters",name],clone_repo)
assert hydrate.returncode==0 and hydrate.stdout.decode().strip()==oid
assert run(["git","--no-lazy-fetch","cat-file","-e",oid],clone_repo).returncode==0
after=run(["git","diff","--name-only","-z","HEAD"],clone_repo)
held.write_bytes(b"X"+payload[1:]);changed=run(["git","diff","--name-only","-z","HEAD"],clone_repo)
held.write_bytes(payload);held.chmod(0o755);mode=run(["git","diff","--name-only","-z","HEAD"],clone_repo)
held.chmod(0o644);held.unlink();deleted=run(["git","diff","--name-only","-z","HEAD"],clone_repo)
result={"scope":"Independent tiny real file:// promisor clone with remote made unavailable; exact original git diff argv, no game/Godot/full-CI execution or budget change.","fixture":str(fixture),"git_version":ok(["git","--version"]).decode().strip(),"blob":oid,"payload_bytes":len(payload),"blob_missing_before_restore":missing.returncode!=0,"git_diff_before_hydrate":{"exit_code":before.returncode,"stdout":before.stdout.decode(errors="replace"),"stderr":before.stderr.decode(errors="replace")},"hash_object_cache_oid":hydrate.stdout.decode().strip(),"git_diff_after_hydrate":{"exit_code":after.returncode,"stdout":after.stdout.decode(errors="replace"),"stderr":after.stderr.decode(errors="replace")},"real_tamper_detected":changed.returncode==0 and name.encode()+b"\0" in changed.stdout,"real_mode_change_detected":mode.returncode==0 and name.encode()+b"\0" in mode.stdout,"real_delete_detected":deleted.returncode==0 and name.encode()+b"\0" in deleted.stdout,"HEAD_unchanged":ok(["git","rev-parse","HEAD"],clone_repo).decode().strip()==head,"index_mode_blob_stage_unchanged":ok(["git","ls-files","--stage"],clone_repo)==index,"commands":commands}
assert before.returncode!=0,result
assert after.returncode==0 and after.stdout==b"",result
assert all(result[k] for k in ["real_tamper_detected","real_mode_change_detected","real_delete_detected","HEAD_unchanged","index_mode_blob_stage_unchanged"]),result
(out/"independent-promisor-result.json").write_text(json.dumps(result,indent=2))
print(json.dumps({k:v for k,v in result.items() if k not in ["commands"]}))
