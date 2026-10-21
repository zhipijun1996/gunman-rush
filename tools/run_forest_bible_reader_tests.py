"""Fast Bible reader/source negatives; never native route or art acceptance."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

if __name__ == "__main__":
    suite = unittest.defaultTestLoader.discover(str(ROOT / "tests"), pattern="test_forest_bible*.py")
    result = unittest.TextTestRunner(verbosity=1).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)
