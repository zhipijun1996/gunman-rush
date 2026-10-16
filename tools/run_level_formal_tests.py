"""Existing Harness specialty: live formal capture integrity, not all routes pass."""
from datetime import datetime, timezone
from pathlib import Path
import subprocess
import uuid

import level_formal
from level_design import ROOT, read, write
from run_tests import run_engine


def main():
    folder=ROOT/"build/verification/level-formal"/(datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")+"-"+uuid.uuid4().hex[:8])
    result=level_formal.capture_one("level-design-v2-baseline",1,"deep",folder/"capture.json",max_ticks=9000)
    if not result["captured"]:
        raise RuntimeError("Actual formal capture integrity failed: "+str(result["errors"]))
    out=run_engine(["--headless","--path",".","--script","tests/level_formal_capture_runner.gd","--","--capture=res://"+(folder/"capture.json").relative_to(ROOT).as_posix()],120)
    if "0 failures" not in out:
        raise RuntimeError("Formal artifact check did not complete")
    data=read(folder/"capture.json")
    data["captured_scope"]["enemy_disable"]=True
    bad=folder/"deliberately_disabled_claim.json";write(bad,data)
    # Deliberate failure runs through the same actual Godot assertion consumer.
    negative=subprocess.run(["bash","tools/godot.sh","--headless","--path",".","--script","tests/level_formal_capture_runner.gd","--","--capture=res://"+bad.relative_to(ROOT).as_posix()],cwd=ROOT,capture_output=True,text=True,timeout=120)
    (folder/"negative.log").write_text(negative.stdout+negative.stderr)
    if negative.returncode==0 or "1 failures" not in negative.stdout:
        raise RuntimeError("Disabled-enemy claim was not rejected")
    print("FORMAL HARNESS: real live capture and deliberate disabled-enemy claim rejected; observed route outcome="+result["outcome"])
    return 0


if __name__=="__main__":raise SystemExit(main())
