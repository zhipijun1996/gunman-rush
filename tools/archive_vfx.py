"""Package the reusable VFX sources and the exact integration diff against frozen Plains."""
import argparse
from pathlib import Path
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BASE = "4f2bb5e41573e930603789c64b52a0c15a6a3dc4"
SOURCE = "4c0a7e5820f90f4d04283c2fafc7c70ef3fa80a7"
PATHS = (
    ".agents/skills/animation-vfx",
    "assets/vfx",
    "assets/audio/vfx_renewal",
    "tools/vfx",
    "tools/build_vfx_renewal_audio.py",
    "tests/vfx",
    "tests/test_vfx_export.py",
    "game/presentation/effects/pixel_vfx.gd*",
    "game/bosses/encounter/boss_roar*",
    "game/presentation/actors/art/boss_roar_screen.gdshader*",
    "docs/project/worklines/vfx_pixelfx_01/scope.md",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", nargs="?", type=Path, default=ROOT / "build/archives/vfx-4c0a7e58.zip")
    output = parser.parse_args().output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output.parent) as staging:
        package = Path(staging) / "vfx.zip"
        subprocess.run(
            ["git", "archive", "--format=zip", f"--output={package}", SOURCE, "--", *PATHS],
            cwd=ROOT, check=True,
        )
        # The shared game scripts also contain unrelated gameplay. Keep their original
        # edits as a patch that can restore the frozen tree (including removed assets).
        diff = subprocess.check_output(
            ["git", "diff", "--binary", "--full-index", "--no-renames", "--no-ext-diff",
             "--no-textconv", BASE, SOURCE, "--"], cwd=ROOT,
        )
        with zipfile.ZipFile(package, "a") as archive:
            entry = zipfile.ZipInfo("integration.patch", archive.infolist()[0].date_time)
            archive.writestr(entry, diff, compress_type=zipfile.ZIP_DEFLATED)
        package.replace(output)
    print(output)


if __name__ == "__main__":
    main()
