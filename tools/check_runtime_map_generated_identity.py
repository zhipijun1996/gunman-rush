"""Run the actual generated-map identity consumer through the shared engine guard."""
import re

from run_tests import run_engine


def run_native(script, marker, timeout):
    """Keep import, fixed simulation clock, teardown and completion checks shared."""
    run_engine(["--headless", "--audio-driver", "Dummy", "--path", ".", "--editor", "--quit"], 90)
    output = run_engine(["--headless", "--audio-driver", "Dummy", "--fixed-fps", "60",
                         "--path", ".", "--script", script], timeout)
    if re.search(r"^ERROR: Resumed function .*class instance is gone", output, re.MULTILINE):
        raise RuntimeError("Generated-map consumer resumed a callback after its owner was freed")
    if re.search(r"^" + re.escape(marker) + r" checks=[1-9][0-9]* failures=0$", output, re.MULTILINE) is None:
        raise RuntimeError("Generated-map consumer did not report its complete successful summary")


def main():
    run_native("tests/runtime_map_generated_identity_runner.gd", "RUNTIME_MAP_GENERATED_IDENTITY", 180)


if __name__ == "__main__":
    main()
