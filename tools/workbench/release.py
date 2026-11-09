"""Package an exact game source, editor catalog and verified Web runtime as one release.

The public feed contains only authored game sources, never private workbench drafts.
GitHub Actions publishes immutable assets; the Site checks this feed on demand.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
import mimetypes
import os
from pathlib import Path
import re
import shutil
import subprocess
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
REPO = "zhipijun1996/gunman-rush"

def encoded(data):
    return (json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode()

def digest(data):
    return hashlib.sha256(data).hexdigest()

def prepare(seed_path: Path, runtime: Path, output: Path, channel: str, site: Path | None = None, retained=False):
    seed = json.loads(seed_path.read_text())
    info = json.loads((runtime / "build-info.json").read_text())
    if not info.get("workbench") or info.get("threads_enabled") or info.get("content_version") != seed["content_version"]:
        raise ValueError("Seed and verified single-thread game runtime do not match")
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    if not re.fullmatch(r"[a-f0-9]{40}", seed["baseline"]):
        raise ValueError("Missing game source baseline")
    if retained:
        if not site:
            raise ValueError("Historical retained bundles may only be embedded in this Site")
        commit = info.get("source_commit", seed["baseline"])
    else:
        if seed["baseline"] != commit or info.get("source_commit") != commit:
            raise ValueError("Seed, runtime and checked-out commit must match exactly")
        source_paths = ["game", "scripts", "scenes", "addons", "config", "resources", "assets", "art", "tools/world", "tools/workbench", "tools/export_workbench.py", "tools/build.py", "project.godot", "export_presets.cfg"]
        changed = subprocess.check_output(["git", "diff", "HEAD", "--name-only", "--", *source_paths], cwd=ROOT, text=True)
        untracked = subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard", "--", *source_paths], cwd=ROOT, text=True)
        if changed.strip() or untracked.strip():
            raise ValueError("Commit the complete game/editor source before preparing a public release")
        import sys
        sys.path.insert(0, str(ROOT / "tools"))
        from export_workbench import manifest as current_manifest
        actual = current_manifest()
        if actual["source_tree_sha256"] != info["source_tree_sha256"]:
            raise ValueError("Game sources changed after runtime export; rebuild the runtime")
    seed_bytes = encoded(seed)
    release_id = digest(encoded({"source_commit": commit, "seed": digest(seed_bytes), "runtime": info["source_tree_sha256"]}))
    tag = "workbench-" + commit
    origin = f"https://github.com/{REPO}/releases/download/{tag}/"
    output.mkdir(parents=True, exist_ok=True)
    files = {}
    for path in sorted(runtime.rglob("*")):
        if not path.is_file():
            continue
        name = path.relative_to(runtime).as_posix()
        if name in {"site-build.json", "build_report.json"}:
            continue
        data = path.read_bytes()
        if len(data) > 8 * 1024 * 1024:
            raise ValueError("Use verified chunk transport before release: " + name)
        sha = digest(data)
        asset = "wb-" + sha + path.suffix
        destination = output / asset
        if not destination.exists():
            destination.write_bytes(data)
        row = {"sha256": sha, "bytes": len(data), "asset": asset,
               "mime": mimetypes.guess_type(name)[0] or "application/octet-stream", "url": origin + asset}
        if site:
            local = site / "public/game-assets" / asset
            local.parent.mkdir(parents=True, exist_ok=True)
            if not local.exists():
                shutil.copyfile(destination, local)
            row["local_path"] = "/game-assets/" + asset
            if path.suffix in {".html", ".js", ".json"}:
                row["text"] = data.decode("utf-8")
        files[name] = row
    if not {"index.html", "index.cache-sw.js", "build-info.json"}.issubset(files):
        raise ValueError("Incomplete runtime transport")
    (output / "workbench-seed.json").write_bytes(seed_bytes)
    manifest = {"schema": "gunman-workbench-release/v1", "id": release_id,
                "provenance": "retained_bundle" if retained else "repository_build",
                "repository": REPO, "source_commit": commit, "source_ref": channel,
                "baseline": seed["baseline"], "content_version": seed["content_version"],
                "runtime_source_sha256": info["source_tree_sha256"],
                "seed": {"url": origin + "workbench-seed.json", "sha256": digest(seed_bytes), "bytes": len(seed_bytes)},
                "files": files}
    public = json.loads(json.dumps(manifest))
    for row in public["files"].values():
        row.pop("local_path", None)
        row.pop("text", None)
    (output / "workbench-release.json").write_bytes(encoded(public))
    channel_data = {"schema": 1, "repository": REPO, "channel": channel, "source_commit": commit,
                    "release_id": release_id, "manifest_url": origin + "workbench-release.json",
                    "manifest_sha256": digest(encoded(public))}
    (output / "channel.json").write_bytes(encoded(channel_data))
    if site:
        folder = site / "lib/workbench/bundled"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / (release_id + ".json")).write_bytes(encoded({"manifest": manifest, "seed": seed}))
    return {"id": release_id, "commit": commit, "tag": tag, "files": len(files), "output": str(output)}

def api(path, data=None, method=None):
    token = os.environ["GH_TOKEN"]
    request = urllib.request.Request("https://api.github.com/repos/" + REPO + "/" + path,
        data=encoded(data) if data is not None else None, method=method,
        headers={"Authorization": "Bearer " + token, "Accept": "application/vnd.github+json",
                 "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "gunman-workbench-release"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)

def publish(output: Path):
    manifest = json.loads((output / "workbench-release.json").read_text())
    channel = json.loads((output / "channel.json").read_text())
    if manifest.get("provenance") != "repository_build" or manifest["baseline"] != manifest["source_commit"]:
        raise ValueError("Only a verified exact repository build can be published to a game channel")
    commit, tag = manifest["source_commit"], "workbench-" + manifest["source_commit"]
    try:
        existing = api("releases/tags/" + tag)
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
        existing = None
    if existing:
        # An immutable tag never gets silently replaced by a different build.
        asset = next((a for a in existing["assets"] if a["name"] == "workbench-release.json"), None)
        if asset:
            with urllib.request.urlopen(asset["browser_download_url"], timeout=60) as response:
                if digest(response.read()) != channel["manifest_sha256"]:
                    raise ValueError("A different release already exists for this source commit")
    else:
        subprocess.run(["gh", "release", "create", tag, "--repo", REPO, "--target", commit,
                        "--title", "工作台游戏版本 " + commit[:10], "--notes", "主游戏导出的组件目录、房间基线与匹配试玩包。", "--prerelease", "--latest=false"], check=True)
    uploaded = {row["name"]: row for row in (existing or {}).get("assets", [])}
    assets = []
    paths = [p for p in sorted(output.iterdir()) if p.is_file() and p.name not in {"channel.json", "workbench-release.json"}]
    paths.append(output / "workbench-release.json")
    for path in paths:
        old = uploaded.get(path.name)
        if old:
            if old.get("state") != "uploaded" or old["size"] != path.stat().st_size:
                raise ValueError("Existing immutable release asset is incomplete or differs: " + path.name)
            continue
        assets.append(str(path))
    # The manifest is last; complete assets remain available during a retry.
    for start in range(0, len(assets), 25):
        subprocess.run(["gh", "release", "upload", tag, "--repo", REPO, *assets[start:start + 25]], check=True)
    # Publish the small channel pointer only after every immutable asset exists.
    branch = "workbench-feed"
    try:
        api("git/ref/heads/" + branch)
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
        tree = api("git/trees", {"tree": []})
        first = api("git/commits", {"message": "Initialize workbench release feed", "tree": tree["sha"], "parents": []})
        api("git/refs", {"ref": "refs/heads/" + branch, "sha": first["sha"]})
    name = "main" if channel["channel"] == "main" else "preview"
    path = "contents/channels/" + name + ".json"
    try:
        old = api(path + "?ref=" + branch)
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
        old = None
    payload = {"message": "Publish workbench " + name + " " + commit[:10], "branch": branch,
               "content": base64.b64encode(encoded(channel)).decode()}
    if old:
        payload["sha"] = old["sha"]
    api(path, payload, "PUT")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["prepare", "publish"])
    parser.add_argument("--seed", type=Path)
    parser.add_argument("--runtime", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--channel", default="main")
    parser.add_argument("--site", type=Path)
    parser.add_argument("--retained", action="store_true", help="Preserve a historical local bundle; never publish it to a channel")
    args = parser.parse_args()
    if args.command == "prepare":
        if not args.seed or not args.runtime:
            parser.error("prepare requires --seed and --runtime")
        print(json.dumps(prepare(args.seed, args.runtime, args.output, args.channel, args.site, args.retained)))
    else:
        publish(args.output)

if __name__ == "__main__":
    main()
