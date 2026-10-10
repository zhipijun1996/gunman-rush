"""Actual GUI smoke for the capability-bound plains_standard Web preview.

Uses screenshots, OCR and ordinary touch/keyboard events, never engine state or
teleport. Retains the historical advanced-course smoke without weakening it.
Default local build/web server; optional deployed URL. Entire run <=180 seconds.
Chromium touch emulation is neither real-device nor whole-route validation.
"""
import asyncio
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

from PIL import ImageChops
from playwright.async_api import async_playwright
import verify_random_stage_browser as helpers
import verify_plains_browser as art

FOLDER = Path("build/verification/plains-capability-browser")
helpers.FOLDER = FOLDER
art.FOLDER = FOLDER


def map_hash(name):
    # Authored static terrain colors only: moving saws/platforms, courier,
    # parallax background, clock and input hints cannot perturb this mask.
    image = helpers.picture(name).crop((0, 150, 1070, 650))
    # Whole-map minification blends SVG green stones into dark olive pixels;
    # broad raw rock tolerance also matches moving bronze/neutral mechanisms.
    # Keep the green-biased stone family (g-b >=12), excluding neutral saws
    # and distant bright background hills. This fingerprints thousands of
    # actual terrain pixels without comparing dynamic-object phases.
    mask = bytes(45 < r < 123 and 5 <= g - r <= 20 and g - b >= 12 and b > 30
                 for r, g, b in image.get_flattened_data())
    if sum(mask) < 150:
        raise RuntimeError("Overview lacks rendered static plains terrain")
    return hashlib.sha256(mask).hexdigest()


async def main(url):
    FOLDER.mkdir(parents=True, exist_ok=True)
    checks, logs, probes = [], [], {}
    report = {"url": url, "checks": checks, "failed": 1,
              "browser": "Chromium mobile touch emulation", "real_android": "unverified",
              "real_iphone_safari": "unverified", "whole_generated_route_browser_traversal": "unverified; first grounded seam only"}
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(
            executable_path=shutil.which("chromium") or shutil.which("chromium-browser"),
            headless=True, args=["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"], timeout=30000)
        try:
            context = await browser.new_context(viewport={"width": 1280, "height": 720}, is_mobile=True, has_touch=True)
            page = await context.new_page()
            page.set_default_timeout(10000)
            page.on("console", lambda message: logs.append(message.text))
            page.on("pageerror", lambda error: logs.append("PAGE ERROR: " + str(error)))
            await page.goto(url, wait_until="networkidle", timeout=45000)
            await page.wait_for_timeout(700)
            report["build_id"] = await page.locator("#playtest-version").get_attribute("data-build-id")
            client = await context.new_cdp_session(page)

            async def capture(name):
                await page.screenshot(path=str(FOLDER / (name + ".png")), timeout=10000)

            async def touch(kind, points):
                await client.send("Input.dispatchTouchEvent", {"type": kind, "touchPoints": points})

            async def overview(name):
                await page.touchscreen.tap(1172, 202)
                await page.wait_for_timeout(200)
                await capture(name)
                digest = map_hash(name)
                world_text = helpers.ocr(name, (0, 150, 1070, 650)).upper()
                if re.search(r"\b(?:ENTRY|EXIT|SECTION)\b|SAFE\s+LINK", world_text):
                    raise RuntimeError("Authoring labels leaked into playable course: " + world_text)
                if "JUMP" in helpers.ocr(name, (895, 620, 1030, 710)).upper():
                    raise RuntimeError("Touch controls obstruct overview")
                return digest

            await capture("home")
            await page.touchscreen.tap(*helpers.text_center("home", "RANDOM STAGE"))
            await page.wait_for_timeout(700)
            await capture("entry")
            initial = helpers.rendered_progress("entry")
            entry_title = helpers.ocr("entry", (15, 8, 1065, 34))
            if "RANDOM" not in entry_title.upper() or initial["route"] != 1 or initial["total"] != 14:
                raise RuntimeError("Actual fourteen-module preview did not start: " + str(initial))
            if "JUMP" not in helpers.ocr("entry", (895, 620, 1030, 710)).upper():
                raise RuntimeError("Mobile play view lacks jump control")
            probes["entry"] = art.rendered_art("entry", courier=False)
            checks.append("Home opens actual fourteen-module generated preview with plains sky/grass/rock and touch controls")
            initial_map = await overview("overview")
            await page.wait_for_timeout(400)
            await capture("overview-frozen")
            if ImageChops.difference(helpers.picture("overview"), helpers.picture("overview-frozen")).getbbox():
                raise RuntimeError("Overview fails to freeze gameplay")
            checks.append("Unobstructed whole-course overview freezes gameplay and has no internal authoring labels")
            await page.touchscreen.tap(1172, 202)
            await page.wait_for_timeout(150)
            sign = -1 if initial["flow"] == "LEFT" else 1
            moved = initial
            for _ in range(8):
                await touch("touchStart", [{"x": 160, "y": 565, "id": 1}])
                await touch("touchMove", [{"x": 160 + 60 * sign, "y": 565, "id": 1}])
                await page.wait_for_timeout(300)
                await touch("touchEnd", [])
                await page.wait_for_timeout(100)
                await capture("touch-seam")
                moved = helpers.rendered_progress("touch-seam")
                if moved["route"] >= 2 and sign * (moved["world_x"] - initial["world_x"]) >= 220:
                    break
            if moved["route"] < 2 or sign * (moved["world_x"] - initial["world_x"]) < 220:
                raise RuntimeError("Real touch movement failed to cross first seamless dock: " + str(moved))
            if abs(moved["camera_x"] - moved["world_x"]) > 630:
                raise RuntimeError("Bounded camera lost the actual moving player")
            probes["courier"] = art.rendered_art("touch-seam")
            report["touch_progress"] = {"initial": initial, "after_touch": moved}
            checks.append("Original courier crosses first seamless dock with real touch input and remains in bounded camera")

            # Reset to safe board. Aim right, pause while held, then release:
            # an erroneous release shot has horizontal recoil visible in HUD X.
            await page.touchscreen.tap(1172, 126)
            await page.wait_for_timeout(500)
            await capture("before-aim-cancel")
            cancel_initial = helpers.rendered_progress("before-aim-cancel")
            await touch("touchStart", [{"x": 1130, "y": 565, "id": 2}])
            await touch("touchMove", [{"x": 1190, "y": 565, "id": 2}])
            await page.wait_for_timeout(150)
            await page.keyboard.press("Escape")
            await page.wait_for_timeout(200)
            await touch("touchEnd", [])
            await capture("paused")
            await page.wait_for_timeout(400)
            await capture("paused-frozen")
            if ImageChops.difference(helpers.picture("paused"), helpers.picture("paused-frozen")).getbbox():
                raise RuntimeError("Pause fails to freeze scene/camera/clock")
            await page.touchscreen.tap(*helpers.text_center("paused", "RESUME"))
            await page.wait_for_timeout(650)
            await capture("after-aim-cancel")
            cancel_after = helpers.rendered_progress("after-aim-cancel")
            if abs(cancel_after["world_x"] - cancel_initial["world_x"]) > 2 or cancel_after["route"] != 1:
                raise RuntimeError("Paused aim release caused unintended horizontal recoil: " + str(cancel_after))
            checks.append("Pause freezes scene; held horizontal aim cancelled by pause produces no release recoil after resume")

            await page.touchscreen.tap(1172, 126)
            await page.wait_for_timeout(500)
            await capture("same-seed-entry")
            retry = helpers.rendered_progress("same-seed-entry")
            if retry["route"] != 1 or abs(retry["world_x"] - initial["world_x"]) > 2:
                raise RuntimeError("Same-seed retry failed to restore entry")
            retry_map = await overview("same-seed-overview")
            if retry_map != initial_map:
                raise RuntimeError("Same-seed retry changed rendered static terrain")
            checks.append("Same-seed retry restores entry and identical rendered static terrain")
            await page.touchscreen.tap(1172, 202)
            await page.wait_for_timeout(100)
            await page.touchscreen.tap(1172, 164)
            await page.wait_for_timeout(500)
            await capture("new-seed-entry")
            if helpers.ocr("new-seed-entry", (15, 8, 1065, 34)) == entry_title:
                raise RuntimeError("New-seed GUI failed to change visible seed")
            next_map = await overview("new-seed-overview")
            if next_map == initial_map:
                raise RuntimeError("New seed did not change rendered static course geometry")
            checks.append("New-seed GUI produces different visible seed and rendered static course geometry")
            if not any("Godot Engine v4.7.2" in entry for entry in logs):
                raise RuntimeError("Pinned Godot 4.7.2 renderer did not start")
            errors = [entry for entry in logs if any(marker in entry for marker in ["SCRIPT ERROR:", "PAGE ERROR:", "Parse Error:", "SHADER ERROR:", "Shader compilation failed"])]
            if errors:
                raise RuntimeError("Actual browser engine errors: " + str(errors))
            checks.append("Actual Godot 4.7.2 Web renderer has no script/parser/shader/browser errors")
            report.update(failed=0, art_pixel_probes=probes,
                          static_terrain_hashes={"initial": initial_map, "retry": retry_map, "new_seed": next_map})
        except BaseException as error:
            report["error"] = str(error) or type(error).__name__
            raise
        finally:
            report["logs"] = logs
            (FOLDER / "browser-report.json").write_text(json.dumps(report, indent=2) + "\n")
            print(json.dumps(report))
            await browser.close()


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8776/"
    server = None
    if target.startswith("http://127.0.0.1:8776"):
        server = subprocess.Popen([sys.executable, "-m", "http.server", "8776", "--bind", "127.0.0.1", "--directory", "build/web"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        asyncio.run(asyncio.wait_for(main(target), timeout=180))
    finally:
        if server:
            server.terminate()
            server.wait(timeout=5)
