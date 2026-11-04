"""Explicit release build: daily checks, current Foundry preparation and selected exports."""
import argparse
import subprocess
import sys

from run_tests import REPO


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=("web", "windows", "android", "all"), default="web", nargs="?")
    parser.add_argument("--plan", action="store_true")
    args = parser.parse_args()
    platforms = ("windows", "web") if args.platform == "all" else (args.platform,)
    commands = [
        ([sys.executable, "tools/ci.py"], 240),
        ([sys.executable, "tools/foundry.py", "build", "--count", "24", "--promote"], 900),
        (["bash", "tools/godot.sh", "--headless", "--path", ".", "--script", "tools/foundry_export_stamp.gd"], 30),
        *[([sys.executable, "tools/build.py", platform], 600) for platform in platforms],
    ]
    if "web" in platforms:
        commands.append(([sys.executable, "tools/check_web_bundle.py"], 120))
    for command, timeout in commands:
        print(" ".join(command), flush=True)
        if not args.plan:
            subprocess.run(command, cwd=REPO, check=True, timeout=timeout)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, subprocess.SubprocessError) as error:
        print(f"Release build failed: {error}", file=sys.stderr)
        sys.exit(1)
