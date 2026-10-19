"""Offline custody verification only; no engine or gameplay acceptance."""
import gzip
import hashlib
import json
from pathlib import Path
import tarfile

base = Path(__file__).resolve().parent
manifest = json.loads((base / "manifest.json").read_text())
sha = lambda data: hashlib.sha256(data).hexdigest()
raws = {row["member"]: row for row in manifest["raw_decoded"]}
count = 0
for name, record in manifest["archives"].items():
    archive = base / name
    data = archive.read_bytes()
    assert len(data) == record["bytes"] and sha(data) == record["sha256"], name
    with tarfile.open(archive, "r:gz") as tar:
        seen = {}
        for member in tar.getmembers():
            assert member.isfile(), member.name
            content = tar.extractfile(member).read()
            seen[member.name] = {"bytes": len(content), "sha256": sha(content)}
            if member.name in raws:
                decoded = gzip.decompress(content)
                json.loads(decoded)
                row = raws[member.name]
                assert len(decoded) == row["uncompressed_bytes"]
                assert sha(decoded) == row["uncompressed_sha256"]
        assert seen == record["members"], name
        count += len(seen)
    index = base / name.replace(".tar.gz", "-index.json")
    assert sha(index.read_bytes()) == record["original_index_sha256"]
for name, row in manifest["direct_files"].items():
    content = (base / name).read_bytes()
    assert len(content) == row["bytes"] and sha(content) == row["sha256"]
print(f"Custody PASS: {count} archive members, all raw gzip JSON and direct review/audit bytes exact.")
