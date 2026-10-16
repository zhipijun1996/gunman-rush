"""Bounded region topology, input-only itineraries and real lifecycle checks."""
import re
import argparse
import contextlib
from datetime import datetime, timezone
import io
import json
from pathlib import Path
import sys
import time
from run_tests import run_engine

SUITES = [
    ("tests/plains_cohesion_drops_runner.gd", r"PLAINS COHESION DROPS: [1-9]\d* assertions, 0 failures", 120),
    ("tests/plains_cohesion_lifecycle_runner.gd", r"PLAINS COHESION LIFECYCLE: [1-9]\d* assertions, 0 failures", 120),
    ("tests/plains_cohesion_runner.gd", r"PLAINS COHESION: [1-9]\d* assertions, 0 failures", 120),
    ("tests/plains_interactive_platforms_runner.gd", r"PLAINS INTERACTIVE PLATFORMS: [1-9]\d* assertions, 0 failures", 120),
    ("tests/plains_interactive_lifecycle_runner.gd", r"PLAINS INTERACTIVE LIFECYCLE: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_platform_boss_runner.gd", r"PLAINS PLATFORM BOSS: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_exploration_pressure_runner.gd", r"PLAINS EXPLORATION PRESSURE: [1-9]\d* assertions, 0 failures", 120),
    ("tests/plains_exploration_module_runner.gd", r"PLAINS EXPLORATION MODULES: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_exploration_expansion_runner.gd", r"PLAINS EXPLORATION EXPANSION: [1-9]\d* assertions, 0 failures", 150),
    ("tests/plains_experience_energy_runner.gd", r"PLAINS EXPERIENCE ENERGY: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_pressure_boss_runner.gd", r"PLAINS PRESSURE BOSS: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_campaign_map_runner.gd", r"PLAINS CAMPAIGN MAP: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_region_runner.gd", r"REGION ASSERTIONS: [1-9]\d* FAILED: 0", 300),
    ("tests/plains_region_lifecycle_runner.gd", r"REGION LIFECYCLE: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_region_boss_runner.gd", r"REGION BOSS: [1-9]\d* assertions, 0 failures", 90),
]

# Explicit legacy ledger:6 sample/fallback routes plus3 families x7 routes.
# The GDScript independently publishes the same28 IDs; neither list can silently omit one.
FIXTURES = ["baseline", "sample/tour", "sample/tutorial_return", "intro-fallback/tour", "intro-fallback/adventure", "advanced-fallback/tour", "advanced-fallback/adventure"]
for _family in ("woven_layers", "linked_rings", "crossroads"):
    FIXTURES.extend(f"intro/{_family}/{mode}" for mode in ("fast", "tour", "adventure"))
    FIXTURES.extend(f"advanced/{_family}/{mode}" for mode in ("fast", "growth", "tour", "adventure"))
assert len(FIXTURES) == len(set(FIXTURES)) == 28
ROOT = Path(__file__).resolve().parents[1]
TOTAL_TIMEOUT = 1500


class Tee(io.StringIO):
    def __init__(self, original):
        super().__init__()
        self.original = original

    def write(self, value):
        self.original.write(value)
        self.original.flush()
        return super().write(value)


def validate_fixture_output(fixture, output):
    if fixture not in FIXTURES:
        raise RuntimeError("Unknown explicit fixture in wrapper ledger")
    if re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|^ERROR:|ObjectDB.*leaked|resources? still in use at exit", output, re.M):
        raise RuntimeError(f"{fixture}: inner engine error or unclean exit")
    inventories = re.findall(r"^REGION FIXTURE INVENTORY: (.+)$", output, re.M)
    if len(inventories) != 1:
        raise RuntimeError(f"{fixture}: missing or repeated actual fixture inventory")
    actual = json.loads(inventories[0])
    if not isinstance(actual, list) or len(actual) != 28 or len(set(actual)) != 28 or sorted(actual) != sorted(FIXTURES):
        raise RuntimeError(f"{fixture}: native/wrapper full28 fixture inventories differ")
    if len(re.findall(r"^REGION ASSERTIONS: [1-9]\d* FAILED: 0$", output, re.M)) != 1:
        raise RuntimeError(f"{fixture}: missing original zero-failure completion summary")
    pattern = rf"^REGION FIXTURE: {re.escape(fixture)} ASSERTIONS: [1-9]\d* FAILED: 0$"
    if len(re.findall(pattern, output, re.M)) != 1 or len(re.findall(r"^REGION FIXTURE: ", output, re.M)) != 1:
        raise RuntimeError(f"{fixture}: missing, wrong or repeated explicit completion receipt")
    if fixture != "baseline":
        mode = fixture.rsplit("/", 1)[-1]
        expected = r"^REGION TUTORIAL RETURN ticks=[1-9]\d* .*safe=true$" if mode == "tutorial_return" else rf"^REGION JOURNEY mode={'deep' if mode=='adventure' else mode} family=\w+ ticks=[1-9]\d* .*safe=true$"
        if len(re.findall(expected, output, re.M)) != 1:
            raise RuntimeError(f"{fixture}: original actual journey/tutorial completion missing")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", action="append", choices=FIXTURES, help="Targeted diagnostics only; default executes all15 suites and all28 legacy fixtures")
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    selected = args.fixture or FIXTURES
    if len(selected) != len(set(selected)):
        parser.error("duplicate explicit fixture request")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    out = args.output_dir or ROOT / "build/verification/plains_region_fixtures" / stamp
    out = out if out.is_absolute() else ROOT / out
    if not out.resolve().is_relative_to((ROOT / "build").resolve()):
        parser.error("output must be under build/")
    out.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    ledger = {"scope":"targeted diagnostic fixtures" if args.fixture else "full original15 suites with legacy27 physical cases and once-only original corpus/App baseline", "expected_full_fixture_ids":FIXTURES,"requested_fixture_ids":selected,"completed_fixture_ids":[],"unfinished_fixture_ids":selected.copy(),"runs":[],"status":"running","total_timeout_seconds":TOTAL_TIMEOUT}

    def save():
        ledger["elapsed_seconds"] = round(time.monotonic()-started,3)
        (out / "ledger.json").write_text(json.dumps(ledger, indent=2)+"\n")

    def execute(name, command, timeout, validate):
        remaining = TOTAL_TIMEOUT-(time.monotonic()-started)
        if remaining <= 0:
            raise RuntimeError("Original overall1500s verification budget exhausted")
        row = {"id":name,"command":command,"timeout_seconds":min(timeout,remaining),"status":"running","exit_code":None}
        ledger["runs"].append(row)
        save()
        run_start=time.monotonic()
        stream=Tee(sys.stdout)
        try:
            with contextlib.redirect_stdout(stream):
                output=run_engine(command,min(timeout,remaining))
            row["exit_code"]=0
            validate(output)
            row["status"]="passed"
            return output
        except BaseException as error:
            row["status"]="failed"
            row["error"]=str(error)
            match=re.search(r"Godot returned (-?\d+)",str(error))
            if match: row["exit_code"]=int(match.group(1))
            raise
        finally:
            row["elapsed_seconds"]=round(time.monotonic()-run_start,3)
            filename=name.replace("/","__")+".log"
            (out / filename).write_text(stream.getvalue())
            row["log"]=filename
            save()

    def fixtures():
        for fixture in selected:
            print(f"Running legacy fixture {fixture}; timeout120s",flush=True)
            execute("fixture/"+fixture,["--headless","--fixed-fps","60","--path",".","--script","tests/plains_region_runner.gd","--",f"--fixture={fixture}"],120,lambda text,f=fixture:validate_fixture_output(f,text))
            ledger["completed_fixture_ids"].append(fixture)
            ledger["unfinished_fixture_ids"].remove(fixture)
            save()
        if ledger["completed_fixture_ids"] != selected or ledger["unfinished_fixture_ids"]:
            raise RuntimeError("Required explicit fixture ledger is incomplete")

    try:
        if args.fixture:
            fixtures()
        else:
            execute("import",["--headless","--path",".","--editor","--quit"],90,lambda _output:None)
            for script, expected, timeout in SUITES:
                if script=="tests/plains_region_runner.gd":
                    fixtures()
                    continue
                print(f"Running {script}; timeout {timeout}s",flush=True)
                def check_summary(output,pattern=expected,name=script):
                    if not re.search("^"+pattern+"$",output,re.M):
                        raise RuntimeError(f"{name}: missing completion summary")
                execute(Path(script).stem,["--headless","--fixed-fps","60","--path",".","--script",script],timeout,check_summary)
        ledger["status"]="passed"
        save()
    except BaseException:
        ledger["status"]="failed"
        save()
        raise
    if args.fixture:
        print(f"PLAINS REGION TARGETED FIXTURES: {len(selected)} passed; full suite not claimed",flush=True)
    else:
        if ledger["completed_fixture_ids"] != FIXTURES:
            raise RuntimeError("Full suite missing required legacy fixture cases")
        print("PLAINS REGION SUITES: 15 suites passed",flush=True)


if __name__ == "__main__":
    main()
