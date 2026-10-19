"""Bounded presentation and touch-menu lifecycles plus the settlement/UI fixture.

The campaign runner retains its declared Boss/reward positioning fixtures. This
does not prove natural traversal, combat completion or visual/player approval.
"""
import re
from run_tests import run_engine

for script, marker in [
    ("tests/parallel_region_presentation_tests.gd", r"^PARALLEL REGION PRESENTATION: [1-9]\d* assertions / 0 failures$"),
    ("tests/forest_campaign_runner.gd", r"^FOREST CAMPAIGN: [1-9]\d* assertions / 0 failures$"),
    ("tests/menu_scroll_touch_tests.gd", r"^MENU SCROLL TOUCH: [1-9]\d* checks / 0 failures; native GUI lifecycle only, Web scrolling separate$"),
]:
    output = run_engine(["--headless", "--fixed-fps", "60", "--path", ".", "--script", script], 120)
    if not re.search(marker, output, re.MULTILINE):
        raise RuntimeError("Missing complete clean presentation consumer: " + script)
print("PASS: parallel region presentation lifecycle and existing campaign UI fixture")
