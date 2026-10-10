"""Historical graybox screenshot/touch smoke of the random-stage Web renderer.

Its graybox palette assertions intentionally remain unchanged for historical
evidence. For the integrated plains artwork use verify_plains_browser.py; do
not interpret this graybox probe failing on a new skin as a gameplay result.

The optional argument is a deployed URL; without it, serve build/web on 8772.
Requires Chromium, Playwright, Pillow and Tesseract. No browser gameplay API,
teleport or page evaluation is used. Mobile emulation is not real-device proof.
"""
import asyncio
import csv
import hashlib
import io
import json
import os
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
        env={**os.environ, "OMP_THREAD_LIMIT": "1"},
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


def rendered_challenges(name, region):
    """Reject a visually flat fallback: read authored shapes from actual pixels."""
    image = picture(name).crop(region)
    platform_rows, spikes, saws, ferries = set(), 0, 0, 0
    for index, (r, g, b) in enumerate(image.get_flattened_data()):
        if max(abs(r - 53), abs(g - 72), abs(b - 91)) < 3:
            platform_rows.add(index // image.width)
        if max(abs(r - 189), abs(g - 87), abs(b - 75)) < 5:
            spikes += 1
        if max(abs(r - 237), abs(g - 119), abs(b - 96)) < 5:
            saws += 1
        if max(abs(r - 89), abs(g - 138), abs(b - 140)) < 3:
            ferries += 1
    vertical_span = max(platform_rows) - min(platform_rows) if platform_rows else 0
    if vertical_span < 90 or spikes < 8 or saws < 8 or ferries < 20:
        raise RuntimeError(f"Overview lacks substantial vertical challenges/spikes/saws/moving platforms: span={vertical_span}, spikes={spikes}, saws={saws}, ferries={ferries}")
    return {"platform_vertical_span_px": vertical_span, "spike_pixels": spikes, "saw_pixels": saws, "moving_platform_pixels": ferries}


def moving_platform_mask(name):
    image = picture(name).crop((0, 145, 1280, 650))
    return bytes(
        1 if max(abs(r - 89), abs(g - 138), abs(b - 140)) < 3 else 0
        for r, g, b in image.get_flattened_data()
    )


def rendered_progress(name):
    text = ocr(name, (15, 32, 1065, 65)).upper()
    route = re.search(r"ROUTE\s+(\d+)\s*[/|]\s*(\d+)", text)
    world = re.search(r"WORLD\s+X\s+([+-]?\d+)", text)
    camera = re.search(r"CAMERA\s+X\s+([+-]?\d+)", text)
    flow = re.search(r"FLOW\s+(LEFT|RIGHT)", text)
    if not route or not world or not camera or not flow:
        raise RuntimeError("Rendered stage/camera progress could not be read: " + text)
    return {"route": int(route[1]), "total": int(route[2]), "world_x": int(world[1]), "camera_x": int(camera[1]), "flow": flow[1], "text": text.strip()}


def text_center(name, phrase):
    """Locate a UI label from screenshots instead of reading game state."""
    result = subprocess.run(
        ["tesseract", str(FOLDER / (name + ".png")), "stdout", "--psm", "11", "tsv"],
        capture_output=True, text=True, timeout=8, check=True,
        env={**os.environ, "OMP_THREAD_LIMIT": "1"},
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

            async def move_direction(sign, duration=500):
                await client.send("Input.dispatchTouchEvent", {
                    "type": "touchStart", "touchPoints": [{"x": 160, "y": 565, "id": 1}]
                })
                await client.send("Input.dispatchTouchEvent", {
                    "type": "touchMove", "touchPoints": [{"x": 160 + 60 * sign, "y": 565, "id": 1}]
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
            direction = -1 if initial["flow"] == "LEFT" else 1
            expected_spawn = 220 if direction == -1 else 20
            if initial["route"] != 1 or initial["total"] != 14 or abs(initial["world_x"] - expected_spawn) > 10:
                raise RuntimeError("Generated preview did not spawn at the safe first module: " + str(initial))
            checks.append("Safe first-board spawn and fourteen-piece progress are visibly rendered")
            if "JUMP" not in ocr("stage-entry", (895, 620, 1030, 710)).upper():
                raise RuntimeError("Actual mobile jump control is missing in play view")

            await page.touchscreen.tap(1172, 202)
            await page.wait_for_timeout(250)
            await capture("whole-stage-overview")
            initial_map = geometry_hash("whole-stage-overview", (0, 145, 1280, 650))
            challenges = rendered_challenges("whole-stage-overview", (0, 145, 1280, 650))
            checks.append("Actual overview contains substantial vertical challenges, spikes, saws and moving platforms")
            if "JUMP" in ocr("whole-stage-overview", (895, 620, 1030, 710)).upper():
                raise RuntimeError("Touch controls obstruct the whole-map overview")
            checks.append("Touch controls are visible in play and hidden for an unobstructed whole-map overview")
            world_text = ocr("whole-stage-overview", (0, 145, 1280, 650)).upper()
            if re.search(r"\b(?:ENTRY|EXIT|SECTION)\b|SAFE\s+LINK|NEXT\s+SECTION", world_text):
                raise RuntimeError("Authoring port or connector labels leaked into playable world: " + world_text)
            checks.append("Overview renders continuous geometry without ENTRY/EXIT or connector labels")
            await page.wait_for_timeout(500)
            await capture("overview-frozen")
            if ImageChops.difference(picture("whole-stage-overview"), picture("overview-frozen")).getbbox():
                raise RuntimeError("Overview failed to pause the actual stage geometry, inputs and game clock")
            checks.append("Whole-stage overview fits the actual mixed-size fourteen-piece map and freezes gameplay")
            first_ferry_mask = moving_platform_mask("whole-stage-overview")
            await page.touchscreen.tap(1172, 202)
            await page.wait_for_timeout(650)
            await page.touchscreen.tap(1172, 202)
            await page.wait_for_timeout(250)
            await capture("moving-platform-phase-overview")
            next_ferry_mask = moving_platform_mask("moving-platform-phase-overview")
            moved_pixels = sum(a != b for a, b in zip(first_ferry_mask, next_ferry_mask))
            if sum(next_ferry_mask) < 20 or moved_pixels < 10:
                raise RuntimeError("Actual moving-platform positions did not change after unpaused gameplay")
            checks.append("Moving-platform pixels change after real unpaused gameplay and freeze in paused overview")
            await page.touchscreen.tap(1172, 202)
            await page.wait_for_timeout(150)

            # Hold the real touch movement stick across two directly joined
            # tiny safe boards. No extra connector, jump or shooting is needed. Observe world/camera coordinates
            # from screenshot text; never set them or inspect engine state.
            progress = initial
            for step in range(10):
                await move_direction(direction, 300)
                await capture("touch-route")
                progress = rendered_progress("touch-route")
                if progress["route"] >= 2 and direction * (progress["world_x"] - initial["world_x"]) >= 220:
                    break
            if direction * (progress["world_x"] - initial["world_x"]) < 220 or progress["route"] < 2:
                raise RuntimeError("Real touch walking did not cross the first grounded seam: " + str(progress))
            if abs(progress["camera_x"] - progress["world_x"]) > 630:
                raise RuntimeError("The actual bounded CameraRig lost the visible player: " + str(progress))
            checks.append("Actual touch walking crosses the first grounded seam across directly coincident module ports")
            checks.append("Rendered bounded CameraRig keeps the actual first-seam touch walk in view")

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
            if retried["route"] != 1 or abs(retried["world_x"] - initial["world_x"]) > 2:
                raise RuntimeError("Retry same seed did not restore the actual safe entry")
            await page.touchscreen.tap(1172, 202)
            await page.wait_for_timeout(200)
            await capture("same-seed-overview")
            retry_map = geometry_hash("same-seed-overview", (0, 145, 1280, 650))
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
            next_map = geometry_hash("new-seed-overview", (0, 145, 1280, 650))
            if next_map == initial_map:
                raise RuntimeError("New seed did not change the actual rendered static module layout")
            checks.append("New seed renders a distinct complete-stage layout")
            await page.touchscreen.tap(1172, 202)
            await page.wait_for_timeout(100)
            # Enter a known deterministic mirrored seed through the visible
            # Godot LineEdit. All gameplay remains ordinary touch input.
            await page.mouse.click(1125, 25)
            await page.wait_for_timeout(150)
            await capture("mirrored-seed-focus")
            await page.keyboard.press("Control+A")
            await page.keyboard.type("left-proof-1", delay=40)
            await capture("mirrored-seed-edited")
            await page.keyboard.press("Enter")
            await page.wait_for_timeout(650)
            await capture("mirrored-stage-entry")
            mirrored_initial = rendered_progress("mirrored-stage-entry")
            mirrored_title = ocr("mirrored-stage-entry", (15, 8, 1065, 34)).upper()
            if "LEFT-PROOF-1" not in mirrored_title or mirrored_initial["flow"] != "LEFT" or mirrored_initial["route"] != 1 or abs(mirrored_initial["world_x"] - 220) > 10:
                raise RuntimeError("GUI-entered mirrored seed did not create the actual left-flow stage: " + str(mirrored_initial))
            mirrored_progress = mirrored_initial
            for step in range(5):
                await move_direction(-1, 300)
                await capture("mirrored-touch-route")
                mirrored_progress = rendered_progress("mirrored-touch-route")
                if mirrored_progress["route"] >= 2 and mirrored_initial["world_x"] - mirrored_progress["world_x"] >= 220:
                    break
            if mirrored_progress["route"] < 2 or mirrored_initial["world_x"] - mirrored_progress["world_x"] < 220:
                raise RuntimeError("Actual left touch input failed to cross the mirrored first seam")
            checks.append("GUI-entered LEFT seed accepts real left-stick motion across its mirrored coincident seam")
            await page.touchscreen.tap(1172, 202)
            await page.wait_for_timeout(250)
            await capture("mirrored-stage-overview")
            rendered_challenges("mirrored-stage-overview", (0, 145, 1280, 650))
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
                "rendered_challenges": challenges,
                "moving_platform_changed_pixels": moved_pixels,
                "static_geometry_hashes": {"initial": initial_map, "same_seed_retry": retry_map, "next_seed": next_map},
                "rendered_progress": {"initial": initial, "after_touch_first_seam": progress, "retry": retried},
                "mirrored_progress": {"seed_text": "left-proof-1", "initial": mirrored_initial, "after_touch_first_seam": mirrored_progress},
                "logs": logs, "browser": "Chromium mobile touch emulation",
                "whole_route_browser_traverse": "unverified; first direct grounded seam only",
                "browser_long_distance_camera_follow": "unverified; independently exercised by actual Motor headless tests",
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
