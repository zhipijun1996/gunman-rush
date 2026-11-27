"""Exercise the rebuild's Android preset and packed game data without an SDK, template, or APK."""
from configparser import ConfigParser
from pathlib import Path
import json
import re
import subprocess
import tempfile

from check_web_bundle import Pack
from godot_identity import environment, verified_engine

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "production"
ENTRY = "res://game/application/world_shell.tscn"


def config(path):
    data = ConfigParser(interpolation=None)
    data.read_string("[header]\n" + path.read_text(encoding="utf-8"), source=str(path))
    return data


def validate_presets():
    project = config(PROJECT / "project.godot")
    preset = config(PROJECT / "export_presets.cfg")
    frozen = config(ROOT / "export_presets.cfg")
    options = preset["preset.0.options"]
    if (project["application"]["run/main_scene"].strip('"') != ENTRY
            or preset["preset.0"]["platform"] != '"Android"'
            or options["architectures/arm64-v8a"] != "true"
            or options["screen/immersive_mode"] != "true"
            or options["package/signed"] != "false"
            or options["package/unique_name"] != '"org.gunmanrush.rebuild"'
            or options["package/unique_name"] == frozen["preset.1.options"]["package/unique_name"]):
        raise ValueError("Android preset must belong to the playable rebuild and enter its world shell")


def validate_pack(pack_path):
    pack = Pack(pack_path)
    lock_root = "config/imported_world/"
    lock = json.loads((PROJECT / lock_root / "current.lock.json").read_text())
    selected = {lock_root + lock[key] for key in ("content_path", "manifest_path")}
    if {name for name in pack.entries if name.startswith(lock_root + "releases/")} != selected:
        raise ValueError("The Android PCK includes a different world version from its release lock")
    bindings = json.loads((PROJECT / lock_root / "bindings.json").read_text())
    rooms = {row["document_path"].removeprefix("res://") for row in bindings["rooms"].values() if "document_path" in row}
    required = selected | rooms | {lock_root + "current.lock.json", lock_root + "bindings.json",
                                   "assets/ui/demo_ui_01/r2/fonts/OFL.txt", "assets/vfx/LICENSE.pixelfx",
                                   "assets/player_presentation_01/weapon_audio_v2/sources/COPYING.adoc",
                                   "config/world_settings_text.json"}
    for path in sorted(required):
        if pack.read(path) != (PROJECT / path).read_bytes():
            raise ValueError("Android PCK changed required raw content " + path)
    forbidden = ("tests/", "addons/", "rooms/world/P02.tscn", "rooms/world/p02_terrace.gd",
                 "scripts/list_mechanisms.gd", "assets/plains_actors_142/source/")
    for name in pack.entries:
        if name.startswith(forbidden) or name.endswith(".zip"):
            raise ValueError("Android PCK contains development-only source: " + name)
    return len(rooms)


def run():
    validate_presets()
    with tempfile.TemporaryDirectory(prefix="gunman-android-pck-") as directory:
        env = {**environment(), "XDG_DATA_HOME": directory}
        path = Path(directory) / "world.pck"
        command = [str(verified_engine()["binary"]), "--headless"]
        for args in (["--path", str(PROJECT), "--export-pack", "Android", str(path)],
                     ["--path", directory, "--main-pack", str(path), "--fixed-fps", "60", "--script",
                      str(PROJECT / "tests/android_foundation.gd"), "--", "--packed"]):
            result = subprocess.run(command + args, cwd=ROOT, env=env, capture_output=True, text=True, timeout=240)
            log = result.stdout + result.stderr
            if result.returncode or re.search(r"^(?:SCRIPT ERROR|ERROR|FAIL)\b", log, re.MULTILINE):
                raise RuntimeError(log[-12000:])
            if "--script" in args and not re.search(r"^ANDROID FOUNDATION checks=\d+ failures=0$", log, re.MULTILINE):
                raise RuntimeError(log[-4000:])
        rooms = validate_pack(path)
        print(f"ANDROID PCK rooms={rooms} failures=0")


if __name__ == "__main__":
    run()
