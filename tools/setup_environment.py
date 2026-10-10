#!/usr/bin/env python3
"""Install the locked Linux x86_64 Standard toolchain outside the Git checkout."""
import argparse
import hashlib
import json
import os
import platform
import shutil
import subprocess
import tarfile
import tempfile
import urllib.parse
import zipfile
from pathlib import Path

from check_environment import CONFIG, DATA, JAVA, REPO, ROOT, SDK, environment


def run(command, timeout=300, input_text=None):
    result = subprocess.run(command, env=environment(), input=input_text, text=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"Command failed with exit code {result.returncode}: {command[0]}")


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def download(spec, name):
    cache = ROOT / "downloads"
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / name
    if not target.is_file() or sha256(target) != spec["sha256"]:
        partial = target.with_suffix(target.suffix + ".partial")
        try:
            # curl respects the session proxy and CA trust; TLS verification remains enabled.
            run(["curl", "--fail", "--location", "--connect-timeout", "10", "--max-time", "180",
                 "--retry", "2", "--output", str(partial), spec["url"]], timeout=600)
            digest = sha256(partial)
            if digest != spec["sha256"]:
                raise RuntimeError(f"SHA256 mismatch for {name}: {digest}")
            partial.replace(target)
        finally:
            partial.unlink(missing_ok=True)
    return target


def unpack_zip(archive, destination):
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as source:
        for member in source.infolist():
            target = (destination / member.filename).resolve()
            if not target.is_relative_to(destination.resolve()):
                raise RuntimeError("Archive contains an unsafe path")
        source.extractall(destination)
        for member in source.infolist():
            mode = member.external_attr >> 16
            if mode and not member.is_dir():
                (destination / member.filename).chmod(mode & 0o777)


def sdk_proxy_flags():
    proxy = urllib.parse.urlparse(os.environ.get("HTTPS_PROXY", os.environ.get("https_proxy", "")))
    if not proxy.hostname:
        return []
    if proxy.username or proxy.password:
        raise RuntimeError("Authenticated SDK proxy requires machine-local JVM configuration; credentials must not enter command arguments")
    if proxy.scheme not in ("http", "https"):
        raise RuntimeError("SDK installation needs an HTTP proxy or an independently configured JVM proxy")
    return ["--proxy=http", "--proxy_host=" + proxy.hostname, "--proxy_port=" + str(proxy.port or 80)]


def trust_proxy_ca():
    # Trust the managed session CA only inside our private toolchain JDK.
    ca = os.environ.get("GUNMAN_PROXY_CA_FILE", os.environ.get("NODE_EXTRA_CA_CERTS", os.environ.get("CODEX_PROXY_CERT", "")))
    if not ca:
        return
    ca_path = Path(ca)
    if not ca_path.is_file():
        raise RuntimeError("Configured session proxy CA file is unavailable")
    if not JAVA.resolve().is_relative_to(ROOT.resolve()):
        raise RuntimeError("Refusing to modify an external JDK truststore; configure its trust independently")
    keytool = JAVA / "bin/keytool"
    store = JAVA / "lib/security/cacerts"
    # changeit is the JDK default store password, not an application credential.
    command = [str(keytool), "-keystore", str(store), "-storepass", "changeit"]
    found = subprocess.run(command + ["-list", "-alias", "gunman-session-proxy"],
                           capture_output=True, text=True, timeout=30)
    if found.returncode:
        run(command + ["-importcert", "-noprompt", "-alias", "gunman-session-proxy",
                       "-file", str(ca_path)], timeout=30)


def configure_editor():
    # Export settings contain machine paths; never write them into the checkout.
    config_root = Path(os.environ.get("XDG_CONFIG_HOME", str(ROOT / "user-config")))
    target = config_root / "godot/editor_settings-4.7.tres"
    target.parent.mkdir(parents=True, exist_ok=True)
    text = target.read_text() if target.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    values = {"export/android/android_sdk_path": str(SDK), "export/android/java_sdk_path": str(JAVA)}
    for key, value in values.items():
        replacement = key + " = " + json.dumps(value)
        lines = text.splitlines()
        matching = [i for i, line in enumerate(lines) if line.startswith(key + " =")]
        if matching:
            lines[matching[0]] = replacement
        else:
            # Editor settings properties belong to the resource section.
            index = next((i + 1 for i, line in enumerate(lines) if line == "[resource]"), None)
            if index is None:
                raise RuntimeError("Existing editor settings lack [resource]; refusing to overwrite")
            lines.insert(index, replacement)
        text = "\n".join(lines) + "\n"
    target.write_text(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot-only", action="store_true")
    parser.add_argument("--accept-android-licenses", action="store_true", help="Accept official Android SDK licenses for this install")
    args = parser.parse_args()
    if platform.system() != "Linux" or platform.machine() not in ("x86_64", "AMD64"):
        raise RuntimeError("Only Linux x86_64 is automated; do not silently choose another engine build")
    if ROOT.resolve().is_relative_to(REPO.resolve()):
        raise RuntimeError("GUNMAN_TOOLCHAIN_ROOT must be outside the repository")
    for command in ("git", "python3", "curl"):
        if not shutil.which(command):
            raise RuntimeError(f"Missing prerequisite {command}; install using the environment's supported package manager")
    engine_dir = ROOT / "godot" / CONFIG["godot"]["version"]
    engine = engine_dir / ("Godot_v" + CONFIG["godot"]["version"] + "-stable_linux.x86_64")
    existing = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if existing and not engine.is_file():
        candidate = subprocess.run([existing, "--version"], capture_output=True, text=True, timeout=30)
        if candidate.returncode == 0 and candidate.stdout.strip().startswith(CONFIG["godot"]["version_prefix"]) and "mono" not in candidate.stdout:
            engine = Path(existing)
        elif os.environ.get("GODOT_BIN"):
            raise RuntimeError("GODOT_BIN does not match the locked Godot Standard version")
    if not engine.is_file():
        unpack_zip(download(CONFIG["godot"]["linux_x86_64"], "godot-linux-x86_64.zip"), engine_dir)
        engine.chmod(0o755)
    result = subprocess.run([str(engine), "--version"], capture_output=True, text=True, timeout=30)
    if result.returncode or not result.stdout.strip().startswith(CONFIG["godot"]["version_prefix"]) or "mono" in result.stdout:
        raise RuntimeError("Installed binary does not match the locked Godot Standard version")
    print(result.stdout.strip())
    template_dir = DATA / "godot/export_templates" / (CONFIG["godot"]["version"] + ".stable")
    required = CONFIG["windows"]["templates"] + ["android_debug.apk", "android_release.apk", "android_source.zip", "linux_debug.x86_64", "linux_release.x86_64"]
    if not all((template_dir / name).is_file() for name in required):
        archive = download(CONFIG["godot"]["templates"], "godot-export-templates.tpz")
        with tempfile.TemporaryDirectory(dir=ROOT) as temp:
            unpack_zip(archive, Path(temp))
            template_dir.mkdir(parents=True, exist_ok=True)
            shutil.copytree(Path(temp) / "templates", template_dir, dirs_exist_ok=True)
    if not args.godot_only:
        if not (JAVA / "bin/java").is_file():
            archive = download(CONFIG["android"]["jdk_linux_x86_64"], "jdk17-linux-x86_64.tar.gz")
            with tempfile.TemporaryDirectory(dir=ROOT) as temp:
                with tarfile.open(archive) as source:
                    source.extractall(temp, filter="data")
                candidates = list(Path(temp).glob("*/bin/java"))
                if len(candidates) != 1:
                    raise RuntimeError("JDK archive layout was unexpected")
                shutil.copytree(candidates[0].parent.parent, JAVA, dirs_exist_ok=True)
        sdkmanager = SDK / "cmdline-tools/latest/bin/sdkmanager"
        if not sdkmanager.is_file():
            archive = download(CONFIG["android"]["command_line_tools"], "android-command-line-tools.zip")
            with tempfile.TemporaryDirectory(dir=ROOT) as temp:
                unpack_zip(archive, Path(temp))
                shutil.copytree(Path(temp) / "cmdline-tools", sdkmanager.parent.parent, dirs_exist_ok=True)
        trust_proxy_ca()
        sdk_command = [str(sdkmanager), "--sdk_root=" + str(SDK)] + sdk_proxy_flags()
        if args.accept_android_licenses:
            run(sdk_command + ["--licenses"], timeout=180, input_text="y\n" * 200)
        missing = [p for p in CONFIG["android"]["sdk_packages"]
                   if not (SDK.joinpath(*p.split(";")) / "source.properties").is_file()]
        if missing and not args.accept_android_licenses:
            raise RuntimeError("Missing SDK packages: repeat with --accept-android-licenses after reviewing official licenses")
        for package in missing:
            run(sdk_command + [package], timeout=600, input_text="y\n" * 200)
        configure_editor()
    command = ["python3", str(REPO / "tools/check_environment.py")]
    if args.godot_only:
        command.append("--godot-only")
    run(command)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.TimeoutExpired, tarfile.TarError, zipfile.BadZipFile) as exc:
        print(f"Environment setup failed: {exc}", file=__import__("sys").stderr)
        raise SystemExit(1)
