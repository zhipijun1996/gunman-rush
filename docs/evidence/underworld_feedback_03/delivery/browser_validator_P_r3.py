#!/usr/bin/env python3
"""Bounded Underworld Plains export, public-byte and rendered GUI evidence.

Uses the existing Web build/cache/prepared Pages transport. This does not grant
art, complete-route, audio, physical-device or whole-project release acceptance.
"""
import argparse
import asyncio
import csv
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
from pathlib import Path
from urllib.parse import parse_qsl, quote, urlencode, urljoin, urlsplit, urlunsplit

ROOT = Path("/workspace/clock-style-preview-k")
ASSETS = ROOT / "assets/underworld_plains"
RAW_UNDERWORLD_PATHS = (
    "assets/underworld_plains/backgrounds/far.png",
    "assets/underworld_plains/backgrounds/middle.png",
    "assets/underworld_plains/backgrounds/near.png",
    "assets/underworld_plains/terrain/source.png",
    "assets/underworld_plains/decor/chime_props.png",
    "assets/underworld_plains/decor/native_underworld.png",
    "assets/underworld_plains/decor/identity_props.png",
)


def sha(path):
    result = hashlib.sha256()
    with path.open("rb") as source:
        while data := source.read(1024 * 1024):
            result.update(data)
    return result.hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def check_raw_sources(pack):
    """Imported derivatives do not substitute for FileAccess-readable bytes."""
    checked = []
    for name in RAW_UNDERWORLD_PATHS:
        if name not in pack.entries:
            raise ValueError("Runtime FileAccess raw PNG missing from actual PCK: " + name)
        path = ROOT / name
        if pack.read(name) != path.read_bytes():
            raise ValueError("Runtime FileAccess raw PNG differs from source bytes: " + name)
        checked.append({"path": name, "sha256": sha(path), "bytes": path.stat().st_size})
    return checked


def check_parallax_hashes(console):
    """Read emitted cooked-runtime observations, not editor-only source hashes."""
    expected = {"res://" + name: sha(ROOT / name) for name in RAW_UNDERWORLD_PATHS[:3]}
    observed = {}
    for line in console:
        if not line.startswith("PIXEL_INSPECT "):
            continue
        fixture = json.loads(line.split(" ", 1)[1])
        for layer in fixture.get("parallax", []):
            name = layer.get("texture_path")
            if name not in expected or layer.get("texture_sha256") != expected[name]:
                raise ValueError("Actual exported parallax raw-source SHA is missing or wrong: " + str(name))
            observed[name] = layer["texture_sha256"]
    if set(observed) != set(expected):
        raise ValueError("Actual exported browser did not observe all three raw-source parallax SHA fields")
    return observed


def underworld_script_consumers():
    """Include the UI/Home/actor adapters outside the art script directory."""
    paths = []
    for path in sorted((ROOT / "scripts").rglob("*.gd")):
        source = path.read_text()
        if "underworld_plains" in path.parts or "Underworld" in source or "res://assets/underworld_plains/" in source:
            paths.append(path)
    return paths


def check_imported_font(pack, name):
    """A declared FontFile must have its actual matching cooked .fontdata."""
    local_import = ROOT / (name + ".import")
    if not local_import.is_file():
        raise ValueError("Runtime font lacks its actual local import: " + name)
    actual = pack.read(name + ".import").decode()
    expected = local_import.read_text()
    if 'type="FontFile"' not in actual:
        raise ValueError("Runtime font import is not FontFile: " + name)
    pattern = r'^path="res://([^"\n]+\.fontdata)"'
    actual_target = re.search(pattern, actual, re.MULTILINE)
    expected_target = re.search(pattern, expected, re.MULTILINE)
    if not actual_target or not expected_target or actual_target.group(1) != expected_target.group(1):
        raise ValueError("Runtime font import target differs from source import: " + name)
    target = actual_target.group(1)
    source_target = ROOT / target
    if not source_target.is_file() or pack.read(target) != source_target.read_bytes():
        raise ValueError("Runtime font cooked bytes differ from source import: " + name)
    return {"path": name, "source_sha256": sha(ROOT / name), "imported_target": target,
            "imported_sha256": sha(source_target), "imported_bytes": source_target.stat().st_size}


def closure(args):
    from check_web_bundle import Pack, texture_import_targets
    from style_exploration_delivery import resource

    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    if head != args.source:
        raise ValueError("Checkout HEAD differs from frozen source")
    runtime_paths = ["scripts", "scenes", "shaders", "assets", "config", "resources", "project.godot", "export_presets.cfg"]
    changed = subprocess.check_output(["git", "diff", "--name-only", args.source, "--", *runtime_paths], cwd=ROOT, text=True)
    unknown = subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard", "--", *runtime_paths], cwd=ROOT, text=True)
    if changed.strip() or unknown.strip():
        raise ValueError("Runtime checkout is not the exact frozen source: " + changed + unknown)
    info = json.loads((args.bundle / "build-info.json").read_text())
    if info["source_commit"] != args.source:
        raise ValueError("Bundle source differs from frozen source")
    pack_path = args.bundle / info["pack"]
    checksum = sha(pack_path)
    if checksum[:12] != info["build_id"] or pack_path.stat().st_size != info["pack_bytes"]:
        raise ValueError("Bundle bytes differ from build ID/length")
    pack = Pack(pack_path)
    checked = {"textures": [], "resources": [], "raw_metadata": [], "fonts": []}
    checked["raw_png"] = check_raw_sources(pack)
    provenance_entries = [name for name in sorted(pack.entries)
                          if name.startswith("assets/underworld_plains/")
                          and any(part in name.split("/") for part in ("generated", "source"))]
    for path in sorted(ASSETS.rglob("*")):
        if not path.is_file() or path.suffix not in {".png", ".svg", ".tres", ".json"}:
            continue
        parts = path.relative_to(ASSETS).parts
        if "generated" in parts or "source" in parts:
            continue
        name = path.relative_to(ROOT).as_posix()
        if path.suffix in {".png", ".svg"}:
            actual = texture_import_targets(pack.read(name + ".import").decode())
            expected = texture_import_targets(path.with_suffix(path.suffix + ".import").read_text())
            if not actual or actual != expected:
                raise ValueError("Texture import targets differ: " + name)
            for target in actual.values():
                if pack.read(target) != (ROOT / target).read_bytes():
                    raise ValueError("Texture derivative differs: " + name)
            checked["textures"].append({"path": name, "source_sha256": sha(path), "targets": actual})
        elif path.suffix == ".json":
            if pack.read(name) != path.read_bytes():
                raise ValueError("Runtime JSON differs or was omitted: " + name)
            checked["raw_metadata"].append({"path": name, "sha256": sha(path)})
        else:
            resource(pack, name)
            checked["resources"].append(name)
    if not checked["textures"] or not checked["resources"]:
        raise ValueError("No actual Underworld texture/TileSet closure checked")
    for directory in ("scripts/underworld_plains",):
        for path in sorted((ROOT / directory).rglob("*")):
            if path.suffix in {".gd", ".gdshader"}:
                name = path.relative_to(ROOT).as_posix()
                resource(pack, name)
                checked["resources"].append(name)
    fonts = set()
    for path in underworld_script_consumers():
        name = path.relative_to(ROOT).as_posix()
        if name not in checked["resources"]:
            resource(pack, name)
            checked["resources"].append(name)
        fonts.update(re.findall(r'(?:preload|load)\(\s*"res://(assets/fonts/[^"\n]+\.(?:ttf|otf))"\s*\)', path.read_text()))
    for name in sorted(fonts):
        checked["fonts"].append(check_imported_font(pack, name))
    components = {}
    for group in ("player_animation", "mechanisms", "home", "ui", "objects"):
        prefix = "assets/underworld_plains/" + group + "/"
        components[group] = {
            "textures": [item["path"] for item in checked["textures"] if item["path"].startswith(prefix)],
            "json": [item["path"] for item in checked["raw_metadata"] if item["path"].startswith(prefix)],
        }
        if (ASSETS / group).is_dir() and (not components[group]["textures"] or not components[group]["json"]):
            raise ValueError("New Underworld component has incomplete actual PNG/JSON export closure: " + group)
    return {"status": "passed", "scope": "actual frozen Underworld runtime PCK closure",
            "source_commit": args.source, "build_id": info["build_id"], "pack": info["pack"],
            "pack_bytes": pack_path.stat().st_size, "pack_sha256": checksum, "checked": checked,
            "nonruntime_provenance_entries": provenance_entries, "components": components}


def public_bytes(args):
    expected = json.loads((args.bundle / "build-info.json").read_text())
    destination = args.output.parent / "public_bytes"
    destination.mkdir(parents=True, exist_ok=True)

    def download(name):
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["curl", "--ipv4", "--fail", "--silent", "--show-error", "--location",
                        "--retry", "3", "--max-time", "240", urljoin(args.url, quote(name)), "--output", str(target)],
                       check=True, timeout=260)
        return target

    actual = json.loads(download("build-info.json").read_text())
    if actual != expected or actual["source_commit"] != args.source:
        raise ValueError("Public build-info differs from exact local export")
    name = actual["pack"]
    pack = download(name)
    checksum = sha(pack)
    if checksum != sha(args.bundle / name) or pack.stat().st_size != actual["pack_bytes"]:
        raise ValueError("Public full PCK differs from frozen export")
    index = download("style-licenses/index.json")
    if index.read_bytes() != (args.bundle / "style-licenses/index.json").read_bytes():
        raise ValueError("Public license index differs")
    checked = []
    for item in json.loads(index.read_text()):
        target = download(item["path"])
        if sha(target) != item["sha256"] or target.stat().st_size != item["bytes"]:
            raise ValueError("Public license bytes differ: " + item["path"])
        checked.append(item)
    return {"status": "passed", "source_commit": args.source, "build_id": actual["build_id"],
            "url": args.url, "pack_sha256": checksum, "pack_bytes": pack.stat().st_size,
            "license_files": checked, "scope": "full public PCK length/SHA and every published license file"}


def query(url, **values):
    parts = urlsplit(url)
    parameters = dict(parse_qsl(parts.query))
    parameters.update(values)
    return urlunsplit(parts._replace(query=urlencode(parameters)))


async def browser(args):
    from PIL import Image, ImageChops, ImageOps
    from playwright.async_api import async_playwright

    folder = args.output.parent / args.output.stem
    folder.mkdir(parents=True, exist_ok=True)
    report = {"status": "failed", "source_commit": args.source, "build_id": args.build_id,
              "url": args.url, "checks": [], "console": [], "http_failures": [], "validator_sha256": sha(Path(__file__)),
              "scope": "actual Chromium canvas, ordinary title and movement; second-map positioned art fixture explicitly separated",
              "physical_device": "unverified", "full_route": "unverified", "audio": "unverified"}
    async with async_playwright() as playwright:
        runtime = await playwright.chromium.launch(executable_path=shutil.which("chromium"), headless=True,
            args=["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
        context = await runtime.new_context(viewport={"width": 1280, "height": 720}, has_touch=True,
            record_video_dir=str(folder / "video"), record_video_size={"width": 1280, "height": 720})
        page = await context.new_page()
        page.on("console", lambda message: report["console"].append(message.text))
        page.on("pageerror", lambda error: report["console"].append("PAGE ERROR: " + str(error)))
        page.on("response", lambda response: report["http_failures"].append(
            {"url": response.url, "status": response.status}) if response.status >= 400 else None)

        async def capture(name):
            path = folder / (name + ".png")
            await page.screenshot(path=str(path))
            return path

        def ocr(path):
            result = subprocess.run(["tesseract", str(path), "stdout", "--psm", "11", "tsv"],
                                    capture_output=True, text=True, check=True, timeout=15, env={**os.environ, "OMP_THREAD_LIMIT": "1"})
            path.with_suffix(".tsv").write_text(result.stdout)
            words = [row for row in csv.DictReader(io.StringIO(result.stdout), delimiter="\t")
                     if row.get("text", "").strip()]
            # Small authored HUD text needs its own pixel-based OCR window.
            # Preserve full originals and exact crop; use full-image word boxes
            # for the ordinary title click, never synthetic GUI coordinates.
            crop = ImageOps.invert(ImageOps.grayscale(Image.open(path).crop((12, 12, 255, 39)))).resize((972, 108))
            hud_path = path.with_name(path.stem + "-hud.png")
            crop.save(hud_path)
            hud = subprocess.run(["tesseract", str(hud_path), "stdout", "--psm", "7"],
                                 capture_output=True, text=True, check=True, timeout=15, env={**os.environ, "OMP_THREAD_LIMIT": "1"})
            hud_path.with_suffix(".txt").write_text(hud.stdout)
            # Build-only pixel sampling adaptation, unchanged Home predicate.
            home_crop = ImageOps.invert(ImageOps.grayscale(Image.open(path).crop((350, 16, 800, 70)))).resize((1350, 162))
            home_path = path.with_name(path.stem + "-home-title.png")
            home_crop.save(home_path)
            home = subprocess.run(["tesseract", str(home_path), "stdout", "--psm", "7"],
                                  capture_output=True, text=True, check=True, timeout=15, env={**os.environ, "OMP_THREAD_LIMIT": "1"})
            home_path.with_suffix(".txt").write_text(home.stdout)
            return words, (" ".join(row["text"] for row in words) + " " + hud.stdout + " " + home.stdout).upper()

        async def load(url):
            await page.goto(url, wait_until="domcontentloaded", timeout=60000)
            await page.wait_for_function("window.PLAYTEST_LOADING_DONE === true", timeout=180000)
            await page.wait_for_timeout(900)
            info = await page.evaluate("async () => (await fetch('build-info.json', {cache:'no-store'})).json()")
            if info["source_commit"] != args.source or info["build_id"] != args.build_id:
                raise ValueError("Actual browser build identity differs")
            if await page.locator("#playtest-version").get_attribute("data-build-id") != args.build_id:
                raise ValueError("Actual canvas build badge differs")
            report["build_info"] = info

        async def click_observed(words, pattern, action):
            rows = {}
            for row in words:
                rows.setdefault(tuple(row[key] for key in ("block_num", "par_num", "line_num")), []).append(row)
            choices = []
            for line in rows.values():
                label = " ".join(row["text"] for row in line).upper()
                if re.search(pattern, label):
                    choices.append((line, label))
            if len(choices) != 1:
                raise ValueError("Actual pointer label missing or ambiguous: " + action + ": " + str([label for _, label in choices]))
            line, label = choices[0]
            left = min(int(row["left"]) for row in line)
            top = min(int(row["top"]) for row in line)
            right = max(int(row["left"]) + int(row["width"]) for row in line)
            bottom = max(int(row["top"]) + int(row["height"]) for row in line)
            await page.mouse.click((left + right) / 2, (top + bottom) / 2)
            report.setdefault("pointer_observations", []).append({"action": action, "observed_text": label,
                "original_pixel_bounds": [left, top, right, bottom]})

        try:
            await load(args.url)
            path = await capture("00-ordinary-title")
            words, text = ocr(path)
            await click_observed(words, r"\bENTER\s+HOME\b", "ordinary title enters actual Home")
            await page.wait_for_timeout(1200)
            path = await capture("00a-home-world-entry")
            _, text = ocr(path)
            if "WINDCHIME HOME" not in text or "NOTES" not in text:
                raise ValueError("Actual new Home world/HUD missing after title pointer: " + text)
            report["checks"].append({"action": "ordinary title pointer enters actual Home settlement", "ocr": text})
            for attempt in range(8):
                await page.keyboard.down("KeyD")
                await page.wait_for_timeout(80)
                await page.keyboard.up("KeyD")
                await page.wait_for_timeout(60)
                path = await capture("00b-home-character-approach-" + str(attempt))
                _, text = ocr(path)
                if "WARDROBE" in text or "CHARACTER" in text:
                    break
            else:
                raise ValueError("Bounded real Home movement never showed its character interaction prompt")
            await page.keyboard.press("KeyW")
            await page.wait_for_timeout(300)
            path = await capture("00c-home-character-panel")
            words, text = ocr(path)
            if "WARDROBE" not in text or "KEEPER" not in text:
                raise ValueError("Actual Home interaction did not open existing character panel: " + text)
            await click_observed(words, r"\bBACK\s+TO\s+HOME\b", "close actual Home character panel")
            await page.wait_for_timeout(300)
            path = await capture("00d-home-panel-closed")
            _, text = ocr(path)
            if "WINDCHIME HOME" not in text:
                raise ValueError("Actual Home panel close did not return to world HUD")
            report["checks"].append({"action": "actual Home movement/W interaction and pointer close", "ocr": text,
                                     "limit": "character selection remains declared development boundary; no purchase or new function granted"})
            await load(args.url)
            path = await capture("00e-ordinary-title-after-home")
            words, text = ocr(path)
            # The decorative title says WINDCHIME; the actual button explicitly
            # says WIND CHIME. Retain that observed distinction in the new UI.
            await click_observed(words, r"\bWIND\s+CHIME\s+PLAINS\b", "ordinary title enters formal map1")
            await page.wait_for_timeout(1600)
            spawn = await capture("01-map1-ordinary-spawn")
            _, text = ocr(spawn)
            if "WINDCHIME PLAINS" not in text or not re.search(r"\b1\s*/\s*2\b", text):
                raise ValueError("Actual formal first map was not accepted: " + text)
            report["checks"].append({"action": "ordinary title mouse enters formal map1", "ocr": text})
            await page.keyboard.down("Space")
            await page.wait_for_timeout(90)
            await capture("01a-map1-stationary-space-early")
            await page.wait_for_timeout(110)
            await capture("01b-map1-stationary-space-later")
            await page.keyboard.up("Space")
            await page.wait_for_timeout(900)
            await capture("01c-map1-stationary-return")
            report["checks"].append({"action": "stationary Space input dispatched before separate horizontal trial",
                                     "limit": "original Actor/platform media independently reviewed; input dispatch alone is not accepted Motor evidence"})
            await page.keyboard.down("KeyD")
            await page.wait_for_timeout(400)
            await page.keyboard.down("Space")
            await page.wait_for_timeout(260)
            moving = await capture("02-map1-real-move-jump")
            await page.keyboard.up("Space")
            await page.wait_for_timeout(400)
            await page.keyboard.up("KeyD")
            await capture("03-map1-after-landing")
            difference = ImageChops.difference(Image.open(spawn).convert("RGB"), Image.open(moving).convert("RGB")).crop((0, 140, 1250, 700)).getbbox()
            if not difference:
                raise ValueError("Actual rendered movement sequence did not change world pixels")
            report["checks"].append({"action": "ordinary KeyD/Space dispatched; captured world pixels changed", "world_pixel_change": list(difference),
                                     "limit": "world pixel change alone does not prove Actor movement or Motor acceptance; independent original-frame review and native Motor traces are separate"})
            await load(query(args.url, plains="1", pixel_inspect="2"))
            await page.wait_for_timeout(1800)
            path = await capture("04-map2-positioned-spawn")
            _, text = ocr(path)
            if "MAP2" not in text and not re.search(r"\b2\s*/\s*2\b", text):
                raise ValueError("Actual positioned second-map fixture missing: " + text)
            report["checks"].append({"action": "second-map built-in positioned art inspection", "ocr": text, "traversal_claim": False})
            for index in range(3):
                await page.mouse.click(440, 20)
                await page.wait_for_timeout(350)
                await capture("05-map2-positioned-landmark-" + str(index))
            await page.keyboard.down("KeyD")
            await page.keyboard.press("Space")
            await page.wait_for_timeout(350)
            await page.keyboard.up("KeyD")
            await capture("06-map2-fixture-real-input")
            await load(query(args.url, styles="1"))
            await page.keyboard.press("Digit4")
            await page.wait_for_timeout(350)
            path = await capture("07-preserved-underworld-style-lab")
            _, text = ocr(path)
            if "UNDERWORLD" not in text:
                raise ValueError("Original experimental style lab no longer accessible: " + text)
            report["checks"].append({"action": "preserved ?styles entry and style4", "ocr": text})
            # R3 additional real Home terrace consumer. All original seven
            # checks above remain. No DOM/private Actor, pose or resource edits.
            await load(args.url)
            path = await capture("08-title-for-terrace")
            words, text = ocr(path)
            await click_observed(words, r"\bENTER\s+HOME\b", "ordinary title enters Home for actual upstairs service")
            await page.wait_for_timeout(1000)
            await capture("08a-home-ground-before-jumps")
            terrace_inputs = []
            for attempt in range(8):
                started = asyncio.get_running_loop().time()
                await page.keyboard.down("KeyD")
                await page.keyboard.down("Space")
                await page.wait_for_timeout(480)
                await page.keyboard.up("Space")
                await page.keyboard.up("KeyD")
                released = asyncio.get_running_loop().time()
                await page.wait_for_timeout(240)
                path = await capture("08b-home-real-jump-terrace-" + str(attempt))
                _, text = ocr(path)
                terrace_inputs.append({"attempt": attempt, "keys": ["KeyD", "Space"], "requested_wait_ms": 480,
                                       "actual_hold_ms": round((released-started)*1000, 2), "all_keys_released_before_screenshot": True,
                                       "observed_upgrade_prompt": "PERMANENT UPGRADES" in text})
                if "PERMANENT UPGRADES" in text:
                    break
            else:
                raise ValueError("Real Home jumps never reached actual upstairs upgrade prompt within eight attempts")
            await page.keyboard.press("KeyW")
            await page.wait_for_timeout(300)
            path = await capture("08c-home-upstairs-upgrade-panel")
            words, text = ocr(path)
            if "PERMANENT VITALITY" not in text:
                raise ValueError("Actual upstairs W did not open original upgrade service: " + text)
            await click_observed(words, r"\bBACK\s+TO\s+HOME\b", "return from actual upstairs upgrade without purchasing")
            await page.wait_for_timeout(300)
            await capture("08d-home-upstairs-after-panel")
            report["terrace_jump_inputs"] = terrace_inputs
            report["checks"].append({"action": "real D/Space jumps reach upstairs upgrade; W opens original service and pointer closes it",
                                     "limit": "fixture-free real browser consumer; interaction guard requires correct floor/tier; video and original pixels reviewed separately, no full Home route/device claim"})
            # A separate safe ground sequence tests both directions. Screenshot
            # follows release, so slow software capture never extends movement.
            await load(args.url)
            path = await capture("09-title-for-direction")
            words, text = ocr(path)
            await click_observed(words, r"\bENTER\s+HOME\b", "ordinary Home for separate left and right input")
            await page.wait_for_timeout(1000)
            await page.mouse.move(1050,360)
            await capture("09a-home-ground-neutral")
            direction_inputs = []
            for code, name in (("KeyD","09b-home-right"),("KeyA","09c-home-left")):
                started = asyncio.get_running_loop().time()
                await page.keyboard.down(code)
                await page.wait_for_timeout(300)
                await page.keyboard.up(code)
                released = asyncio.get_running_loop().time()
                await page.wait_for_timeout(80)
                await capture(name)
                direction_inputs.append({"key":code,"requested_wait_ms":300,"actual_hold_ms":round((released-started)*1000,2),"released_before_screenshot":True})
            report["home_direction_input_dispatches"] = direction_inputs
            report["checks"].append({"action":"separate real Home D and A inputs captured after release","limit":"input dispatch and actual pixels; accepted Motor direction remains independently reviewed native/browser media"})
            errors = [line for line in report["console"] if any(token in line for token in
                ("SCRIPT ERROR:", "Parse Error:", "SHADER ERROR:", "PAGE ERROR:", "Resource file not found:", "Failed to load script"))]
            if errors:
                raise ValueError("Actual runtime emitted script/resource/shader errors: " + str(errors))
            if [row for row in report["http_failures"] if not row["url"].endswith("/favicon.ico")]:
                raise ValueError("Actual Web asset HTTP failure")
            if not any("Godot Engine v4.7.2" in line for line in report["console"]):
                raise ValueError("Expected engine did not report startup")
            report["raw_parallax_source_hashes"] = check_parallax_hashes(report["console"])
            report["status"] = "passed"
        except BaseException as error:
            report["error"] = str(error)
            raise
        finally:
            await context.close()
            await runtime.close()
            write(args.output, report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("closure", "public-bytes", "browser"))
    parser.add_argument("--bundle", type=Path, default=ROOT / "build/web")
    parser.add_argument("--source", required=True)
    parser.add_argument("--build-id")
    parser.add_argument("--url")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command in ("public-bytes", "browser") and not args.url:
        parser.error("--url is required")
    if args.command == "browser" and not args.build_id:
        parser.error("--build-id is required")
    result = asyncio.run(browser(args)) if args.command == "browser" else globals()[args.command.replace("-", "_")](args)
    write(args.output, result)
    print(json.dumps({key: result.get(key) for key in ("status", "source_commit", "build_id", "pack_bytes", "pack_sha256")}, ensure_ascii=False))


if __name__ == "__main__":
    main()
