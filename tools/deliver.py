"""Explicit fixed-world delivery: daily checks and controlled platform exports."""
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
        *[([sys.executable, "tools/export_runtime.py", "--output", "build/web", "--max-pack-mib", "180"] if platform=="web" else [sys.executable, "tools/export_native.py", platform], 600) for platform in platforms],
    ]
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
