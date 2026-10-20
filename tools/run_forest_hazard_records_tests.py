"""Keep all recorded forest thorn rectangles aligned with their damage records."""
import json
import re
from pathlib import Path
from run_tests import run_engine


def main():
    path = Path("build/forest_revision04/hazard-records.json")
    output = run_engine([
        "--headless", "--path", ".", "--script", "tests/forest_hazard_records_runner.gd",
        "--", "--output=res://" + path.as_posix(),
    ], 90)
    report = json.loads(path.read_text())
    if (not re.search(r"^FOREST HAZARD RECORDS: [1-9]\d* checks / 0 failures$", output, re.M)
            or report.get("failures") != 0 or not report.get("cases")
            or not report.get("checks") or not all(row.get("passed") is True for row in report["checks"])):
        raise RuntimeError("Forest hazard metadata proof is incomplete")


if __name__ == "__main__":
    main()
