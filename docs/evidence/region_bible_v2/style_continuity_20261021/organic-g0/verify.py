from pathlib import Path
import hashlib,json,zipfile,zlib
p=Path(__file__).resolve().parent
m=json.loads((p/"member-manifest.json").read_text())
zp=p/m["archive"]
assert hashlib.sha256(zp.read_bytes()).hexdigest()==m["archive_sha256"]
with zipfile.ZipFile(zp) as z:
 assert z.testzip() is None
 assert sorted(z.namelist())==sorted(r["member"] for r in m["members"])
 for r in m["members"]:
  b=z.read(r["member"])
  assert len(b)==r["bytes"] and hashlib.sha256(b).hexdigest()==r["sha256"]
  assert format(zlib.crc32(b)&0xffffffff,"08x")==r["crc32"]
 read=lambda q:json.loads(z.read(q))
 first=read(m["first"]["receipt"]);second=read(m["second"]["receipt"])
 assert first["exit_code"]==first["native_exit_code"]==1
 assert second["exit_code"]==second["native_exit_code"]==0
 assert first["sources_before"]==first["sources_after"]
 assert second["sources_before"]==second["sources_after"]
 for run,expected in [("first",27),("second",28)]:
  folder=m[run]["receipt"].rsplit("/",1)[0]
  cap=read(folder+"/capture.json")
  assert len(cap["checks"])==28 and sum(x["observed"] for x in cap["checks"])==expected
  for row in cap["rows"]:
   assert hashlib.sha256(z.read(folder+"/"+row["image"])).hexdigest()==m["pngs_same_across_engineering_runs"][row["image"]]
 assert read(m["independent_report"])["verdict"]==m["art_verdict"]
print(json.dumps({"verified":True,"archive_sha256":m["archive_sha256"],"members":m["member_count"],"bytes":m["archive_bytes"],"first":"FAIL27/28","second":"PASS28/28","art":m["art_verdict"]}))
