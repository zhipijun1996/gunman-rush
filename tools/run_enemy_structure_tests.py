#!/usr/bin/env python3
"""Run the real enemy-structure contract consumer; no visual-quality claims.

Import uses the existing 90-second bound; the new native consumer has a declared
180-second bound. Engine ownership belongs to the caller, who must serialize it.
"""
import argparse
import contextlib
import json
from pathlib import Path
import re
import subprocess
import sys

from run_tests import run_engine
import harness

ROOT = Path(__file__).resolve().parents[1]
PLAINS = ("patrol", "charger", "diver", "hopper", "sentry", "fan_sentry", "root_bell")
FOREST = ("forest_lantern", "forest_seed_sentry", "forest_swing_pod", "forest_bark_beetle", "forest_thread_spider", "forest_crossbranch", "forest_bible_weaver")
BOSSES = ("clockwork_guardian", "bellstrider", "windkeeper", "thorn_guardian", "thorn_queen", "rootbell_guardian_v2", "thorn_queen_v2", "thorn_queen_canopy", "windkeeper_storm")
EXPECTED_CASES = {f"ordinary/{identity}/{profile}" for identity in PLAINS for profile in ("scene", "underworld")}
EXPECTED_CASES |= {f"ordinary/{identity}/forest" for identity in FOREST}
EXPECTED_CASES |= {f"candidate/{identity}/{context}" for identity in ("candidate_lure_guard", "candidate_crosswind_moth") for context in ("lab", "studio")}
EXPECTED_CASES |= {f"boss/{identity}" for identity in BOSSES}
EXPECTED_CASES |= {"ordinary/root_bell/root_bell", "registry/refusals", "binding/replacements", "lifecycle/rebind", "boss-lifecycle/rebind"}
MARKER = re.compile(r"^ENEMY STRUCTURE: ([1-9]\d*) checks, 0 failures$", re.M)


class Tee:
    def __init__(self, terminal, log):
        self.terminal, self.log = terminal, log

    def write(self, value):
        self.log.write(value)
        self.log.flush()
        return self.terminal.write(value)

    def flush(self):
        self.log.flush()
        self.terminal.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--skip-import", action="store_true", help="Caller already completed current-source import; no engine work is skipped otherwise.")
    args = parser.parse_args()
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=False)
    report = {"scope": "Native structural contract fixtures only; no visual/user/device acceptance", "status": "running", "import_budget_seconds": 90, "runner_budget_seconds": 180}
    try:
        with (output_dir / "native.log").open("w") as log, contextlib.redirect_stdout(Tee(sys.stdout, log)):
            if not args.skip_import:
                imported = run_engine(["--headless", "--audio-driver", "Dummy", "--path", ".", "--editor", "--quit"], 90)
                if re.search(r"(?m)^(?:SCRIPT |SHADER )?ERROR:|Parse Error:", imported):
                    raise RuntimeError("Unexpected native import error")
            report["source_before"] = harness.git_metadata()
            text = run_engine(["--headless", "--audio-driver", "Dummy", "--fixed-fps", "60", "--path", ".", "--script", "tests/enemy_structure_runner.gd", "--", "--output=" + str(output_dir / "runtime.json")], 180)
            report["source_after"] = harness.git_metadata()
            report["source_stable"] = report["source_before"] == report["source_after"]
            if not report["source_stable"]:
                raise RuntimeError("Source changed during native structure test")
            if re.search(r"(?m)^(?:SCRIPT |SHADER )?ERROR:|Parse Error:", text):
                raise RuntimeError("Unexpected native runtime error")
            marker = MARKER.search(text)
            if marker is None:
                raise RuntimeError("Missing complete nonzero structure-test marker")
            data = json.loads((output_dir / "runtime.json").read_text())
            if data.get("failures") or data.get("checks") != int(marker.group(1)):
                raise RuntimeError("Native result and completion marker disagree")
            rows = data.get("cases", [])
            identifiers = [row.get("id") for row in rows]
            if len(identifiers) != len(set(identifiers)) or set(identifiers) != EXPECTED_CASES or any(not row.get("passed") for row in rows):
                raise RuntimeError("Duplicate, failed or missing independently enumerated roster cases")
            report.update(status="passed", checks=data["checks"], cases=len(rows))
            print("PASS: enemy structure native contracts (not visual acceptance)")
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        report.update(status="failed", error=str(error))
        raise
    finally:
        (output_dir / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"Enemy structure verification failed: {error}", file=sys.stderr)
        sys.exit(1)
