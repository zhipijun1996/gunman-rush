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
import re
import shutil
import subprocess
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urljoin, urlsplit, urlunsplit

ROOT = next(parent for parent in Path(__file__).resolve().parents if (parent / "project.godot").is_file())
ASSETS = ROOT / "assets/underworld_plains"


def sha(path):
    result = hashlib.sha256()
    with path.open("rb") as source:
        while data := source.read(1024 * 1024):
            result.update(data)
    return result.hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


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
    checked = {"textures": [], "resources": [], "raw_metadata": []}
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
    return {"status": "passed", "scope": "actual frozen Underworld runtime PCK closure",
            "source_commit": args.source, "build_id": info["build_id"], "pack": info["pack"],
            "pack_bytes": pack_path.stat().st_size, "pack_sha256": checksum, "checked": checked,
            "nonruntime_provenance_entries": provenance_entries}


def public_bytes(args):
    expected = json.loads((args.bundle / "build-info.json").read_text())
    destination = args.output.parent / "public_bytes"
    destination.mkdir(parents=True, exist_ok=True)

    def download(name):
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["curl", "--ipv4", "--fail", "--silent", "--show-error", "--location",
                        "--retry", "3", "--max-time", "240", urljoin(args.url, name), "--output", str(target)],
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
                                    capture_output=True, text=True, check=True, timeout=15)
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
                                 capture_output=True, text=True, check=True, timeout=15)
            hud_path.with_suffix(".txt").write_text(hud.stdout)
            return words, (" ".join(row["text"] for row in words) + " " + hud.stdout).upper()

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

        try:
            await load(args.url)
            path = await capture("00-ordinary-title")
            words, text = ocr(path)
            # Locate the actual first formal-entrance line, excluding the lab.
            rows = {}
            for row in words:
                rows.setdefault(tuple(row[key] for key in ("block_num", "par_num", "line_num")), []).append(row)
            choices = []
            for line in rows.values():
                label = " ".join(row["text"] for row in line).upper()
                if "PLAINS" in label and "LAB" not in label and "WIND" in label:
                    choices.append(line)
            if len(choices) != 1:
                raise ValueError("Formal title entry missing/ambiguous in actual pixels: " + text)
            line = choices[0]
            left = min(int(row["left"]) for row in line)
            top = min(int(row["top"]) for row in line)
            right = max(int(row["left"]) + int(row["width"]) for row in line)
            bottom = max(int(row["top"]) + int(row["height"]) for row in line)
            await page.mouse.click((left + right) / 2, (top + bottom) / 2)
            await page.wait_for_timeout(1600)
            spawn = await capture("01-map1-ordinary-spawn")
            _, text = ocr(spawn)
            if "WINDCHIME PLAINS" not in text or not re.search(r"\b1\s*/\s*2\b", text):
                raise ValueError("Actual formal first map was not accepted: " + text)
            report["checks"].append({"action": "ordinary title mouse enters formal map1", "ocr": text})
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
            report["checks"].append({"action": "ordinary KeyD/Space accepted by rendered game", "world_pixel_change": list(difference),
                                     "limit": "fresh native Motor acceptance and exact parallax ratios are separately tested"})
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
            errors = [line for line in report["console"] if any(token in line for token in
                ("SCRIPT ERROR:", "Parse Error:", "SHADER ERROR:", "PAGE ERROR:", "Resource file not found:", "Failed to load script"))]
            if errors:
                raise ValueError("Actual runtime emitted script/resource/shader errors: " + str(errors))
            if [row for row in report["http_failures"] if not row["url"].endswith("/favicon.ico")]:
                raise ValueError("Actual Web asset HTTP failure")
            if not any("Godot Engine v4.7.2" in line for line in report["console"]):
                raise ValueError("Expected engine did not report startup")
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
