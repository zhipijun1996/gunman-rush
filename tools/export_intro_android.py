#!/usr/bin/env python3
"""Build an isolated, installable ARM64 review of the production opening rooms."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

from godot_identity import REPO, environment, verified_engine, verify_templates

ENTRY = "res://rooms/world/P02.tscn"
PACKAGE = "org.gunmanrush.review.plains"
PRESET = f'''[preset.0]
name="Opening Android"
platform="Android"
runnable=true
export_filter="all_resources"
include_filter="*.json,*.txt,*.bin,*.sha256"
exclude_filter=""

[preset.0.options]
gradle_build/use_gradle_build=false
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
package/unique_name="{PACKAGE}"
package/name="Gunman Rush · Plains Review"
package/signed=false
version/code=1
screen/immersive_mode=true
'''


def run(command, env):
    subprocess.run([str(item) for item in command], env=env, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="Destination .apk file")
    args = parser.parse_args()
    output = args.output.resolve()
    if output.suffix.lower() != ".apk":
        parser.error("output must be an .apk file")
    output.parent.mkdir(parents=True, exist_ok=True)
    env = environment()
    sdk = Path(env["ANDROID_HOME"])
    build_tools = sdk / "build-tools/35.0.1"
    java = Path(env["JAVA_HOME"]) if env.get("JAVA_HOME") else Path(shutil.which("java")).resolve().parents[1]
    tools = [java / "bin/keytool", build_tools / "zipalign", build_tools / "apksigner", build_tools / "aapt"]
    for tool in tools:
        if not tool.is_file():
            parser.error(f"missing Android/JDK tool {tool}")
    keytool, zipalign, signer, aapt = tools
    engine = verified_engine()["binary"]
    verify_templates()
    source = REPO / "production"
    with tempfile.TemporaryDirectory(prefix="gunman-intro-android-") as work:
        base = Path(work)
        stage = base / "project"
        def excluded(folder, names):
            parent = Path(folder)
            skipped = {name for name in names if (parent / name / ".gdignore").is_file()}
            if parent == source:
                skipped.update((".godot", ".gdignore", "addons", "tests"))
            return skipped

        shutil.copytree(source, stage, ignore=excluded)
        project = stage / "project.godot"
        settings = project.read_text().splitlines()
        settings = [line for line in settings if not line.startswith("run/main_scene=")]
        settings = [line for line in settings if not line.startswith("textures/vram_compression/import_etc2_astc=")]
        settings.insert(settings.index("[rendering]") + 1, "textures/vram_compression/import_etc2_astc=true")
        settings.insert(settings.index("[application]") + 1, f'run/main_scene="{ENTRY}"')
        settings = [line.replace('PackedStringArray("res://addons/mechanism_library/plugin.cfg")',
                                 "PackedStringArray()") for line in settings]
        project.write_text("\n".join(settings) + "\n")
        (stage / "export_presets.cfg").write_text(PRESET)
        env["XDG_CONFIG_HOME"] = str(base / "editor")
        config = base / "editor/godot/editor_settings-4.7.tres"
        config.parent.mkdir(parents=True)
        config.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
                          'export/android/shutdown_adb_on_exit = false\n'
                          f'export/android/android_sdk_path = {json.dumps(str(sdk))}\n'
                          f'export/android/java_sdk_path = {json.dumps(str(java))}\n')
        godot = [engine, "--headless", "--path", stage]
        run(godot + ["--editor", "--import", "--quit"], env)
        unsigned = base / "unsigned.apk"
        run(godot + ["--export-debug", "Opening Android", unsigned], env)
        aligned = base / "aligned.apk"
        run([zipalign, "-f", "-P", "16", "4", unsigned, aligned], env)
        # This machine reuses its debug key. Ephemeral CI runners create independent review certificates.
        key_dir = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "gunman-review"
        key_dir.mkdir(parents=True, exist_ok=True)
        keystore = key_dir / "android-debug.keystore"
        if not keystore.exists():
            run([keytool, "-genkeypair", "-keystore", keystore, "-storepass", "android",
                 "-alias", "androiddebugkey", "-keypass", "android", "-dname", "CN=Gunman Review",
                 "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000"], env)
            keystore.chmod(0o600)
        signed = base / "signed.apk"
        run([signer, "sign", "--ks", keystore, "--ks-pass", "pass:android", "--ks-key-alias",
             "androiddebugkey", "--out", signed, aligned], env)
        run([signer, "verify", "--verbose", signed], env)
        run([zipalign, "-c", "-P", "16", "4", signed], env)
        manifest = subprocess.check_output([aapt, "dump", "xmltree", signed, "AndroidManifest.xml"], env=env, text=True)
        if f'package="{PACKAGE}"' not in manifest:
            raise ValueError("Review package ID differs from the preset")
        with zipfile.ZipFile(signed) as apk:
            libraries = {name.split("/")[1] for name in apk.namelist() if name.endswith("/libgodot_android.so")}
            if libraries != {"arm64-v8a"}:
                raise ValueError(f"Unexpected Godot libraries in APK: {libraries}")
            for room in ("P01", "P02", "P03"):
                rel = f"rooms/world/{room}.json"
                if apk.read("assets/" + rel) != (stage / rel).read_bytes():
                    raise ValueError(f"Wrong room document in APK: {rel}")
            if ENTRY.encode() not in apk.read("assets/project.binary"):
                raise ValueError("Wrong APK engine entry point")
        # Replace only after the exported package has passed signature and content verification.
        with tempfile.NamedTemporaryFile(dir=output.parent, suffix=".apk", delete=False) as temp:
            published = Path(temp.name)
            with signed.open("rb") as stream:
                shutil.copyfileobj(stream, temp)
        published.replace(output)
    with output.open("rb") as stream:
        print(output, output.stat().st_size, hashlib.file_digest(stream, "sha256").hexdigest())


if __name__ == "__main__":
    main()
