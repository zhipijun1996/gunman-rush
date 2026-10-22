"""Plan minimum relevant existing Harness checks; unknown impact stays conservative.

This is a routing layer, not another test runner or a release approval. A plan
records no test success. Release remains owned by tools/deliver.py and CI.
"""
import argparse
from datetime import datetime, timezone
import fnmatch
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
POLICY = ROOT / "config/production_impact.json"


def unique(items):
    return list(dict.fromkeys(items))


def validate_policy(policy, manifest):
    if policy.get("schema_version") != 1:
        raise ValueError("Unsupported impact policy schema")
    domains = policy["domains"]
    for name, domain in domains.items():
        for stage in ("development", "integration"):
            if any(check not in manifest["checks"] for check in domain[stage]):
                raise ValueError("Unknown Harness check in domain: " + name)
        if any(dep not in domains for dep in domain["depends_on"]):
            raise ValueError("Unknown dependency in domain: " + name)
    for rule in policy["rules"]:
        if not rule["paths"] or rule["domain"] not in domains:
            raise ValueError("Invalid impact rule: " + str(rule.get("id")))
    if len({rule["id"] for rule in policy["rules"]}) != len(policy["rules"]):
        raise ValueError("Repeated impact rule ID")
    for profile in ("docs", "full"):
        if not manifest["profiles"].get(profile):
            raise ValueError("Missing existing Harness profile: " + profile)
    domain_closure(domains, list(domains))


def domain_closure(domains, requested):
    ordered, visiting, visited = [], set(), set()

    def visit(name):
        if name in visiting:
            raise ValueError("Impact dependency cycle: " + name)
        if name in visited:
            return
        visiting.add(name)
        for dependency in domains[name]["depends_on"]:
            visit(dependency)
        visiting.remove(name)
        visited.add(name)
        ordered.append(name)

    for name in requested:
        visit(name)
    return ordered


def safe_path(path):
    if not path or "\\" in path or PurePosixPath(path).is_absolute() or ".." in PurePosixPath(path).parts:
        raise ValueError("Unsafe changed path: " + repr(path))
    return path


def make_plan(paths, stage, policy, manifest, jobs=1):
    validate_policy(policy, manifest)
    if stage not in ("development", "integration", "release"):
        raise ValueError("Unknown production stage")
    paths = sorted({safe_path(path) for path in paths})
    matches, selected_domains, escalations = [], [], []
    for path in paths:
        # Only the planner policy itself may precede config/* fail-closed routing.
        planner = next((r for r in policy["rules"] if r["id"] == "planner" and path in r["paths"]), None)
        forced = not planner and any(fnmatch.fnmatchcase(path, pattern) for pattern in policy["always_full"])
        rules = [planner] if planner else [r for r in policy["rules"] if any(fnmatch.fnmatchcase(path, p) for p in r["paths"])]
        if forced or not rules:
            reason = "Shared runtime/configuration/build boundary" if forced else "Unknown or unregistered dependency scope"
            escalations.append({"path": path, "reason": reason, "to": "full"})
            matches.append({"path": path, "rules": [], "reason": reason, "scope": "full"})
        else:
            selected_domains.extend(r["domain"] for r in rules)
            matches.append({"path": path, "rules": [r["id"] for r in rules], "reason": [r["reason"] for r in rules], "scope": "mapped"})
    closure = domain_closure(policy["domains"], unique(selected_domains))
    if stage == "integration":
        for domain in closure:
            if policy["domains"][domain].get("full_integration"):
                escalations.append({"domain": domain, "reason": "Shared interface and consumer reachability require the existing full integration baseline", "to": "full"})
    full = bool(escalations)
    checks = manifest["profiles"]["docs"][:]
    if full:
        checks.extend(manifest["profiles"]["full"])
    else:
        for domain in closure:
            checks.extend(policy["domains"][domain][stage if stage != "release" else "integration"])
    commands = [["python3", "tools/harness.py", *[arg for check in unique(checks) for arg in ("--check", check)], "--jobs", str(jobs)]]
    if stage == "integration":
        commands[0].append("--release")
    if stage == "release":
        checks = []
        commands = [["python3", "tools/deliver.py", "--jobs", str(jobs)]]
    return {
        "schema_version": 1, "stage": stage, "status": "planned", "approval_scope": "plan_only",
        "changed_paths": paths, "path_reasons": matches, "domains": closure,
        "escalations": escalations, "selection": "original_release_delivery" if stage == "release" else ("full" if full else "affected_checks"),
        "checks": unique(checks), "commands": commands,
        "additional_commands": [["python3", "tests/test_production_plan.py"]] if "planner" in closure and stage != "release" else [],
        "release_follow_up": ["Run the existing exact-SHA CI release and deploy jobs.", "Verify the published build using tools/verify_published_build.py with the actual URL, build ID and source commit.", "Report independent review, player acceptance and real devices separately."] if stage == "release" else [],
        "manual_checks": policy["manual_checks"],
        "device_acceptance": "unverified", "player_acceptance": "unverified"
    }


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, timeout=30).strip()


def run_commands(commands, root, results, guard=lambda: None):
    """Stop at the first actual failure; guard source before and after each call."""
    for command in commands:
        guard()
        actual = [sys.executable if arg == "python3" else arg for arg in command]
        result = subprocess.run(actual, cwd=root, check=False)
        results.append({"argv": actual, "exit_code": result.returncode})
        guard()
        if result.returncode:
            return result.returncode
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="origin/main")
    parser.add_argument("--stage", choices=("development", "integration", "release"), default="development")
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--plan", action="store_true", help="Default: record selection, never test success")
    action.add_argument("--execute", action="store_true", help="Execute selected Development/Integration checks through the original Harness")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--jobs", type=int, default=1, choices=range(1, 9))
    args = parser.parse_args(argv)
    import harness
    policy = json.loads(POLICY.read_text())
    manifest = harness.load_manifest()
    base_sha = git("rev-parse", "--verify", args.base + "^{commit}")
    head_sha = git("rev-parse", "HEAD")
    plan = make_plan(harness.changed_paths(base_sha), args.stage, policy, manifest, args.jobs)
    source_metadata = harness.git_metadata()
    plan.update(base_commit=base_sha, source_commit=head_sha, git_status=git("status", "--porcelain"),
                working_files=source_metadata["working_files"],
                policy_sha256=hashlib.sha256(POLICY.read_bytes()).hexdigest(),
                manifest_sha256=hashlib.sha256(harness.MANIFEST.read_bytes()).hexdigest())
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    output = args.output or ROOT / "build/verification/production-plan" / stamp / "plan.json"
    output = output if output.is_absolute() else ROOT / output
    # A requested report must not overwrite source, old evidence or other files.
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("x") as stream:
        stream.write(json.dumps(plan, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(plan, ensure_ascii=False, indent=2), flush=True)
    print("Production plan: " + str(output), flush=True)
    if not args.execute:
        return 0
    if args.stage == "release":
        print("Release is plan-only here: execute tools/deliver.py and the existing exact-SHA release/deployment workflow; a Harness full run alone is not release acceptance.", file=sys.stderr)
        return 2
    results = []
    exit_code = 1
    def source_guard():
        if harness.git_metadata() != source_metadata:
            raise RuntimeError("Source/Git changed during planned verification; create a fresh plan")
    try:
        exit_code = run_commands(plan["additional_commands"] + plan["commands"], ROOT, results, source_guard)
        return exit_code
    finally:
        # Separate execution receipt; never turn a plan into a test result.
        receipt = {"schema_version": 1, "stage": args.stage, "plan": str(output), "source_commit": head_sha,
                   "status": "selected_commands_succeeded" if exit_code == 0 else "failed_or_interrupted",
                   "steps": results, "device_acceptance": "unverified", "player_acceptance": "unverified"}
        receipt_path = output.with_name(output.stem + ".execution.json")
        with receipt_path.open("x") as stream:
            stream.write(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        print("Production planning failed: " + str(error), file=sys.stderr)
        sys.exit(1)
