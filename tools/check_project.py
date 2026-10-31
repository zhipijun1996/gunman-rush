"""Check that the current development entry points remain usable."""
from pathlib import Path
import re
import sys
from harness import load_manifest
from quality import policy
from project_dependencies import inspect as inspect_dependencies

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = ["AGENTS.md", "README.md", "docs/current_state.md", "docs/harness.md",
            "docs/project_structure.md", "docs/templates/iteration.md",
            "docs/archive/agents_before_harness.md", "docs/archive/readme_before_harness.md"]
SKILLS = policy()["core_skills"] + ["project-integration"]


def main():
    errors = []
    errors.extend(inspect_dependencies(ROOT)["errors"])
    for path in REQUIRED:
        if not (ROOT / path).is_file():
            errors.append(f"Missing entry: {path}")
    for name in SKILLS:
        path = ROOT / ".agents/skills" / name / "SKILL.md"
        if not path.is_file():
            errors.append(f"Missing skill: {name}")
            continue
        content = path.read_text()
        if not re.match(r"---\nname: " + re.escape(name) + r"\ndescription: .+\n---\n", content):
            errors.append(f"Invalid skill metadata: {name}")
        if f".agents/skills/{name}/SKILL.md" not in (ROOT / "AGENTS.md").read_text():
            errors.append(f"Skill not discoverable from AGENTS: {name}")
    for directory in ("docs", "preview", "build"):
        if not (ROOT / directory / ".gdignore").is_file():
            errors.append(f"Documentation/preview import isolation missing: {directory}")
    for path in (ROOT / "tests").glob("*.gd"):
        content = path.read_text()
        if re.search(r'FileAccess\.open\([^\n]*res://docs/evidence/[^\n]*FileAccess\.WRITE', content):
            errors.append(f"Test overwrites archived evidence: {path.name}")
    try:
        data = load_manifest()
        for profile in ("docs", "core", "gameplay", "art", "web", "full"):
            if "docs" not in data["profiles"].get(profile, []):
                errors.append(f"Profile lacks required docs check: {profile}")
        required = set(data["profiles"]["gameplay"] + data["profiles"]["art"] + data["profiles"]["web"])
        if set(data["profiles"]["full"]) != required:
            errors.append("Full profile must preserve all constituent checks")
    except (ValueError, KeyError, OSError) as error:
        errors.append(str(error))
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"PASS: project structure, {len(SKILLS)} skills and harness profiles. Runtime not tested.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
