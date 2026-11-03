"""Verify the installed pinned files and the complete existing installer tests.

Neither command downloads or reads the original candidate archive.
"""
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]


def main():
    for command in ([sys.executable, "-B", "tools/install_mapgen_candidate.py", "verify-installed"],
                    [sys.executable, "-B", "tests/test_install_mapgen_candidate.py"]):
        subprocess.run(command, cwd=ROOT, check=True, timeout=30)


if __name__ == "__main__":
    main()
