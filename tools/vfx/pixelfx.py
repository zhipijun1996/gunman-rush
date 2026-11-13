#!/usr/bin/env python3
"""Pinned, project-local pixelfx authoring. No runtime dependency or global install."""
from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
UPSTREAM = "https://github.com/patch-gg/pixelfx.git"
REVISION = "5294518ce7c72e48b6100a744596e0acf57f2826"
CHECKOUT = ROOT / "build/vfx/pixelfx"
SOURCES = ROOT / "tools/vfx/effects"
PREVIEWS = ROOT / "build/vfx/previews"


def run(args: list[str], cwd: Path = ROOT) -> None:
    subprocess.run(args, cwd=cwd, check=True)


def prepare() -> Path:
    if not shutil.which("node") or not shutil.which("git"):
        raise SystemExit("pixelfx authoring requires Git and Node 18+.")
    major = subprocess.check_output(["node", "--version"], text=True).strip().lstrip("v").split(".")[0]
    if int(major) < 18:
        raise SystemExit("pixelfx authoring requires Node 18+.")
    if not (CHECKOUT / ".git").exists():
        CHECKOUT.mkdir(parents=True, exist_ok=True)
        run(["git", "init", "--quiet"], CHECKOUT)
        run(["git", "remote", "add", "origin", UPSTREAM], CHECKOUT)
    current = subprocess.run(["git", "rev-parse", "HEAD"], cwd=CHECKOUT, text=True, capture_output=True)
    if current.returncode or current.stdout.strip() != REVISION:
        run(["git", "fetch", "--depth", "1", "origin", REVISION], CHECKOUT)
        run(["git", "checkout", "--detach", REVISION], CHECKOUT)
    target = CHECKOUT / "src/fx/gunman"
    target.mkdir(parents=True, exist_ok=True)
    source_files = {p.name: p for p in SOURCES.glob("*.js")}
    for old in target.glob("*.js"):
        if old.name not in source_files:
            old.unlink()
    for name, source in source_files.items():
        shutil.copyfile(source, target / name)
    return CHECKOUT


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["setup", "list", "render", "check", "act", "export"])
    args, tail = parser.parse_known_args()
    checkout = prepare()
    if args.command == "setup":
        print(f"pixelfx {REVISION}: {checkout}")
        return
    if args.command == "export":
        run(["node", str(ROOT / "tools/vfx/export.mjs"), str(checkout), *tail])
        return
    command = ["node", f"tools/{args.command}.mjs", *tail]
    if args.command in ("render", "act") and "--out" not in tail:
        command.extend(["--out", str(PREVIEWS)])
    if args.command == "check" and not tail:
        command.append("gunman")
    run(command, checkout)


if __name__ == "__main__":
    main()
