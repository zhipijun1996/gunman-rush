"""Bounded screenshot/touch smoke of the actual random-stage Web renderer.

The optional argument is a deployed URL; without it, serve build/web on 8772.
Requires Chromium, Playwright, Pillow and Tesseract. No browser gameplay API,
teleport or page evaluation is used. Mobile emulation is not real-device proof.
"""
import asyncio
import csv
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

from PIL import Image, ImageChops
from playwright.async_api import async_playwright


FOLDER = Path("build/verification/random-stage-browser")


def picture(name):
    return Image.open(FOLDER / (name + ".png")).convert("RGB")


def ocr(name, region=None):
    """Read only rendered pixels, with a bounded external OCR process."""
    image = picture(name)
    if region:
        image = image.crop(region)
    path = FOLDER / (name + "-ocr.png")
    image.resize((image.width * 2, image.height * 2)).save(path)
    result = subprocess.run(
        ["tesseract", str(path), "stdout", "--psm", "6"],
        capture_output=True, text=True, timeout=8, check=True,
    )
    return result.stdout


def geometry_hash(name, region):
    # The grey authored platform fill is static. Ignore the moving saw/ferry,
    # player, port glyphs and runtime clock rather than mistaking their phase
    # for changed map content. This is renderer evidence, not reachability.
    image = picture(name).crop(region)
    mask = bytes(
        1 if max(abs(r - 53), abs(g - 72), abs(b - 91)) < 3 else 0
        for r, g, b in image.get_flattened_data()
    )
    if sum(mask) < 500:
        raise RuntimeError("Overview did not visibly render full-stage static platform geometry")
    return hashlib.sha256(mask).hexdigest()


def rendered_progress(name):
    text = ocr(name, (15, 32, 1065, 65)).upper()
    section = re.search(r"SECTION\s+(\d+)\s*[/|]\s*(\d+)", text)
    world = re.search(r"WORLD\s+X\s+(\d+)", text)
    camera = re.search(r"CAMERA\s+X\s+(\d+)", text)
    if not section or not world or not camera:
        raise RuntimeError("Rendered stage/camera progress could not be read: " + text)
    return {"section": int(section[1]), "total": int(section[2]), "world_x": int(world[1]), "camera_x": int(camera[1]), "text": text.strip()}


def text_center(name, phrase):
    """Locate a UI label from screenshots instead of reading game state."""
    result = subprocess.run(
        ["tesseract", str(FOLDER / (name + ".png")), "stdout", "--psm", "11", "tsv"],
        capture_output=True, text=True, timeout=8, check=True,
    )
    rows = list(csv.DictReader(io.StringIO(result.stdout), delimiter="\t"))
    words = [row for row in rows if row.get("text", "").strip()]
    wanted = phrase.upper().split()
    for start in range(len(words) - len(wanted) + 1):
        found = words[start:start + len(wanted)]
        if [row["text"].strip().upper() for row in found] == wanted:
            left = min(int(row["left"]) for row in found)
            right = max(int(row["left"]) + int(row["width"]) for row in found)
            top = min(int(row["top"]) for row in found)
            bottom = max(int(row["top"]) + int(row["height"]) for row in found)
            return ((left + right) / 2, (top + bottom) / 2)
    raise RuntimeError("Rendered UI label missing: " + phrase + "; OCR words: " + str([row["text"] for row in words]))


async def main(url):
    FOLDER.mkdir(parents=True, exist_ok=True)
    checks, logs = [], []
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(
            executable_path=shutil.which("chromium") or shutil.which("chromium-browser"),
            headless=True,
            args=["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"],
            timeout=30000,
        )
        try:
            context = await browser.new_context(
                viewport={"width": 1280, "height": 720}, is_mobile=True, has_touch=True
            )
            page = await context.new_page()
            page.on("console", lambda message: logs.append(message.text))
            page.on("pageerror", lambda error: logs.append("PAGE ERROR: " + str(error)))
            await page.goto(url, wait_until="networkidle", timeout=45000)
            await page.wait_for_timeout(700)
            build_id = await page.locator("#playtest-version").get_attribute("data-build-id")
            (FOLDER / "loaded-build.json").write_text(json.dumps({"url": page.url, "build_id": build_id}) + "\n")

            async def capture(name):
                await page.screenshot(path=str(FOLDER / (name + ".png")))

            client = await context.new_cdp_session(page)

            async def move_right(duration=500):
                await client.send("Input.dispatchTouchEvent", {
                    "type": "touchStart", "touchPoints": [{"x": 160, "y": 565, "id": 1}]
                })
                await client.send("Input.dispatchTouchEvent", {
                    "type": "touchMove", "touchPoints": [{"x": 220, "y": 565, "id": 1}]
                })
                await page.wait_for_timeout(duration)
                await client.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})

            await capture("home")
            # UI coordinates below are kept alongside the preview UI contract.
            await page.touchscreen.tap(*text_center("home", "RANDOM STAGE"))
            await page.wait_for_timeout(700)
            await capture("stage-entry")
            entry_text = ocr("stage-entry", (15, 8, 1065, 34))
            if "RANDOM" not in entry_text.upper():
                raise RuntimeError("Home RANDOM STAGE did not display the actual generated-stage HUD: " + entry_text)
            checks.append("Home RANDOM STAGE enters an actual generated stage")

            initial = rendered_progress("stage-entry")
            if initial["section"] != 1 or initial["total"] != 7 or not 110 <= initial["world_x"] <= 130:
                raise RuntimeError("Generated preview did not spawn at the safe first module: " + str(initial))
            checks.append("Safe first-module spawn and seven-module progress are visibly rendered")

            await page.touchscreen.tap(1172, 202)
            await page.wait_for_timeout(250)
            await capture("whole-stage-overview")
            initial_map = geometry_hash("whole-stage-overview", (0, 230, 1280, 650))
            await page.wait_for_timeout(500)
            await capture("overview-frozen")
            if ImageChops.difference(picture("whole-stage-overview"), picture("overview-frozen")).getbbox():
                raise RuntimeError("Overview failed to pause the actual stage geometry, inputs and game clock")
            checks.append("Whole-stage overview fits the actual seven-module map and freezes gameplay")
            await page.touchscreen.tap(1172, 202)
            await page.wait_for_timeout(150)

            # Hold the real touch movement stick. The first safe hub and its
            # seam need no jump or shooting. Observe world/camera coordinates
            # from screenshot text; never set them or inspect engine state.
            progress = initial
            for step in range(10):
                await move_right(600)
                await capture("touch-route")
                progress = rendered_progress("touch-route")
                if progress["section"] >= 2:
                    break
            if progress["world_x"] <= 1480 or progress["section"] < 2:
                raise RuntimeError("Real touch walking did not cross the first grounded seam: " + str(progress))
            if progress["camera_x"] - initial["camera_x"] < 300:
                raise RuntimeError("The actual CameraRig failed to follow beyond the first screen: " + str(progress))
            checks.append("Actual touch walking crosses the first grounded seam into section two")
            checks.append("Rendered CameraRig follows the player beyond the first screen")

            await page.touchscreen.tap(1220, 35)
            await page.wait_for_timeout(200)
            await capture("paused")
            await page.wait_for_timeout(600)
            await capture("paused-later")
            if ImageChops.difference(picture("paused"), picture("paused-later")).getbbox():
                raise RuntimeError("Pause failed to freeze the full generated scene and camera")
            checks.append("Pause freezes generated geometry, camera and game clock")
            await page.touchscreen.tap(*text_center("paused", "SETTINGS"))
            await page.wait_for_timeout(200)
            await capture("settings")
            if "Input settings" not in ocr("settings"):
                raise RuntimeError("The generated-stage pause menu did not open input settings")
            checks.append("Shared input settings remain accessible in generated-stage practice")
            # The existing shared settings dialog intentionally scrolls at
            # 720 px height. Use an ordinary GUI wheel event to expose Back;
            # touch gameplay checks above remain actual touch input.
            await page.mouse.move(1010, 550)
            await page.mouse.wheel(0, 600)
            await page.wait_for_timeout(150)
            await capture("settings-scrolled")
            await page.touchscreen.tap(*text_center("settings-scrolled", "BACK"))
            await page.wait_for_timeout(150)
            await capture("pause-returned")
            await page.touchscreen.tap(*text_center("pause-returned", "RESUME"))
            await page.wait_for_timeout(200)

            await page.touchscreen.tap(1172, 126)
            await page.wait_for_timeout(500)
            await capture("same-seed-retry")
            retried = rendered_progress("same-seed-retry")
            if retried["section"] != 1 or abs(retried["world_x"] - initial["world_x"]) > 2:
                raise RuntimeError("Retry same seed did not restore the actual safe entry")
            await page.touchscreen.tap(1172, 202)
            await page.wait_for_timeout(200)
            await capture("same-seed-overview")
            retry_map = geometry_hash("same-seed-overview", (0, 230, 1280, 650))
            if retry_map != initial_map:
                raise RuntimeError("Same-seed retry changed the rendered static full-stage layout")
            checks.append("Retry same seed restores entry and reproduces visible static map geometry")
            await page.touchscreen.tap(1172, 202)
            await page.wait_for_timeout(100)
            await page.touchscreen.tap(1172, 164)
            await page.wait_for_timeout(500)
            await capture("new-seed-entry")
            if ocr("new-seed-entry", (15, 8, 1065, 34)) == entry_text:
                raise RuntimeError("New seed did not change the visible seed label")
            await page.touchscreen.tap(1172, 202)
            await page.wait_for_timeout(200)
            await capture("new-seed-overview")
            next_map = geometry_hash("new-seed-overview", (0, 230, 1280, 650))
            if next_map == initial_map:
                raise RuntimeError("New seed did not change the actual rendered static module layout")
            checks.append("New seed renders a distinct complete-stage layout")
            await page.touchscreen.tap(1172, 202)
            await page.wait_for_timeout(100)
            await page.touchscreen.tap(1220, 35)
            await page.wait_for_timeout(200)
            await capture("pause-home")
            await page.touchscreen.tap(*text_center("pause-home", "RETURN TO HOME"))
            await page.wait_for_timeout(150)
            await capture("confirm-home")
            await page.touchscreen.tap(*text_center("confirm-home", "LEAVE RUN"))
            await page.wait_for_timeout(400)
            await capture("returned-home")
            if ImageChops.difference(picture("home"), picture("returned-home")).getbbox():
                raise RuntimeError("Leaving generated practice changed the rendered Home/run/meta summary")
            checks.append("Confirmed leave returns Home with its original run/meta summary")

            if not any("Godot Engine v4.7.2" in entry for entry in logs):
                raise RuntimeError("The pinned Godot engine did not start")
            if any(marker in entry for entry in logs for marker in [
                "SCRIPT ERROR:", "PAGE ERROR:", "Parse Error:", "SHADER ERROR:", "Shader compilation failed"
            ]):
                raise RuntimeError("Browser engine error: " + str(logs))
            report = {
                "checks": checks, "url": page.url,
                "build_id": build_id,
                "static_geometry_hashes": {"initial": initial_map, "same_seed_retry": retry_map, "next_seed": next_map},
                "rendered_progress": {"initial": initial, "after_touch_first_seam": progress, "retry": retried},
                "logs": logs, "browser": "Chromium mobile touch emulation",
                "whole_route_browser_traverse": "unverified; first grounded seam only",
                "real_android": "unverified", "real_iphone_safari": "unverified",
            }
            (FOLDER / "browser-report.json").write_text(json.dumps(report, indent=2) + "\n")
            print(json.dumps(report))
        finally:
            await browser.close()


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8772/"
    server = None
    if target.startswith("http://127.0.0.1:8772"):
        server = subprocess.Popen(
            [sys.executable, "-m", "http.server", "8772", "--bind", "127.0.0.1", "--directory", "build/web"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    try:
        asyncio.run(asyncio.wait_for(main(target), timeout=180))
    finally:
        if server:
            server.terminate()
            server.wait(timeout=5)
