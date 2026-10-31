#!/usr/bin/env python3
"""Execute tool checks and emit a portable evidence report; any required failure exits 1."""
import argparse
import json
import os
import platform
import re
import shutil
import subprocess
from pathlib import Path

import godot_identity

REPO = Path(__file__).resolve().parent.parent
CONFIG = json.loads((REPO / "config/toolchain.json").read_text())
ROOT = Path(os.environ.get("GUNMAN_TOOLCHAIN_ROOT", str(REPO.parent / "toolchains")))
SDK = Path(os.environ.get("ANDROID_HOME", str(ROOT / "android-sdk")))
JAVA = Path(os.environ.get("JAVA_HOME", str(ROOT / "jdk17")))
DATA = godot_identity.data_root(CONFIG, REPO)


def environment():
    return godot_identity.environment(CONFIG, REPO)


def portable(text):
    # Reports can be committed without recording machine-specific installation paths.
    for path, marker in sorted([(str(ROOT), "$GUNMAN_TOOLCHAIN_ROOT"),
                                (str(SDK), "$ANDROID_HOME"), (str(JAVA), "$JAVA_HOME"),
                                (str(REPO), "$REPO"), (str(Path.home()), "$HOME")],
                               key=lambda item: len(item[0]), reverse=True):
        text = text.replace(path, marker)
    return text


def command_check(name, command, predicate=None):
    try:
        result = subprocess.run(command, capture_output=True, text=True, env=environment(), timeout=90)
        output = (result.stdout + result.stderr).strip()
        passed = result.returncode == 0 and (predicate(output) if predicate else True)
        code = result.returncode
    except (OSError, subprocess.TimeoutExpired) as exc:
        output, passed, code = str(exc), False, 127 if isinstance(exc, OSError) else 124
    return {"name": name, "command": portable(" ".join(map(str, command))),
            "exit_code": code, "passed": passed, "output": portable(output)}


def version_at_least(output, minimum):
    found = re.search(r"(\d+)\.(\d+)", output)
    return bool(found and tuple(map(int, found.groups())) >= tuple(map(int, minimum.split("."))))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot-only", action="store_true", help="Exclude Android SDK/JDK checks")
    parser.add_argument("--output", type=Path, help="Write the same portable JSON report to a file")
    args = parser.parse_args()
    checks = [command_check("git", ["git", "--version"], lambda s: version_at_least(s, CONFIG["git_minimum"])),
              command_check("python", ["python3", "--version"], lambda s: version_at_least(s, CONFIG["python_minimum"])),
              command_check("godot_standard", ["bash", str(REPO / "tools/godot.sh"), "--version"],
                            lambda s: s == CONFIG["godot"]["version_exact"])]
    try:
        lock = godot_identity.validate_lock(CONFIG, REPO)
        templates = godot_identity.verify_templates(CONFIG, REPO)
        checks.append({"name": "templates_source_and_member_sha256", "command": "verify complete fixed template distribution",
                       "exit_code": 0, "passed": True, "output": lock["build_id"]})
        for filename, digest in lock["templates"]["files"].items():
            checks.append({"name": "template:" + filename, "command": "verify locked SHA256",
                           "exit_code": 0, "passed": True, "sha256": digest})
    except (OSError, RuntimeError, KeyError, ValueError) as error:
        checks.append({"name": "templates_source_and_member_sha256", "command": "verify complete fixed template distribution",
                       "exit_code": 1, "passed": False, "output": portable(str(error))})
    if not args.godot_only:
        java = str(JAVA / "bin/java") if (JAVA / "bin/java").is_file() else "java"
        checks.extend([command_check("java", [java, "-version"],
                                     lambda s: bool(re.search(r'version "(17|1[89]|[2-9][0-9])\.', s))),
                       command_check("sdkmanager", [str(SDK / "cmdline-tools/latest/bin/sdkmanager"), "--version"]),
                       command_check("adb", [str(SDK / "platform-tools/adb"), "version"]),
                       command_check("aapt2", [str(SDK / "build-tools/35.0.1/aapt2"), "version"])])
        for package in CONFIG["android"]["sdk_packages"]:
            path = SDK.joinpath(*package.split(";")) / "source.properties"
            properties = {}
            if path.is_file():
                for line in path.read_text().splitlines():
                    if "=" in line and not line.lstrip().startswith("#"):
                        key, value = line.split("=", 1)
                        properties[key.strip()] = value.strip()
            revision = properties.get("Pkg.Revision", "")
            expected_revision = {"build-tools;35.0.1": "35.0.1", "cmake;3.10.2.4988404": "3.10.2",
                                 "ndk;28.1.13356709": "28.1.13356709"}.get(package)
            passed = bool(revision) and (expected_revision is None or revision == expected_revision)
            if package == "platform-tools":
                passed = passed and version_at_least(revision, "35.0")
            if package == "platforms;android-35":
                passed = passed and properties.get("AndroidVersion.ApiLevel") == "35"
            checks.append({"name": "sdk:" + package, "command": "read source.properties and validate revision",
                           "exit_code": 0 if passed else 1, "passed": passed,
                           "output": "Pkg.Revision=" + revision + "; AndroidVersion.ApiLevel=" + properties.get("AndroidVersion.ApiLevel", "n/a")})
    report = {"system": platform.system(), "architecture": platform.machine(),
              "scope": "godot-all-templates" if args.godot_only else "godot-all-templates-android-sdk",
              "checks": checks, "missing_or_failed": [c["name"] for c in checks if not c["passed"]],
              "limitations": ["Windows execution requires separate Windows validation",
                              "Android device input, performance and feel require physical-device validation",
                              "SDK availability does not demonstrate APK export"]}
    encoded = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    print(encoded, end="")
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded)
    return int(bool(report["missing_or_failed"]))


if __name__ == "__main__":
    raise SystemExit(main())
