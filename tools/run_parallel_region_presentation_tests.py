"""Bounded presentation lifecycle plus existing explicit settlement/UI fixture.

The campaign runner retains its declared Boss/reward positioning fixtures. This
does not prove natural traversal, combat completion or visual/player approval.
"""
import re
from run_tests import run_engine

for script, marker in [
    ("tests/parallel_region_presentation_tests.gd", r"^PARALLEL REGION PRESENTATION: [1-9]\d* assertions / 0 failures$"),
    ("tests/forest_campaign_runner.gd", r"^FOREST CAMPAIGN: [1-9]\d* assertions / 0 failures$"),
]:
    output = run_engine(["--headless", "--fixed-fps", "60", "--path", ".", "--script", script], 120)
    if not re.search(marker, output, re.MULTILINE):
        raise RuntimeError("Missing complete clean presentation consumer: " + script)
print("PASS: parallel region presentation lifecycle and existing campaign UI fixture")
