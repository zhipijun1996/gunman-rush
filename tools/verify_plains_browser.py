"""Bounded smoke of plains artwork in the actual Godot Web renderer.

Run from the repository root; optional deployed URL, otherwise local build/web.
All interactions are visible GUI/CDP touch input, never engine state or teleport.
Color probes use authored SVG palettes, not the retired graybox assertions.
Chromium mobile emulation does not constitute Android/iPhone device validation.
"""
import asyncio
import json
import hashlib
import re
from pathlib import Path
import shutil
import subprocess
import sys

from PIL import Image, ImageChops
from playwright.async_api import async_playwright
import verify_random_stage_browser as helpers

FOLDER = Path("build/verification/plains-browser")
helpers.FOLDER = FOLDER
PALETTES = {
    "grass": [(143, 159, 79), (79, 101, 58), (215, 204, 115)],
    "rock": [(114, 119, 106), (75, 81, 74), (49, 58, 54)],
    "courier_cream": [(245, 238, 219), (241, 230, 201)],
    "courier_scarf": [(167, 69, 54)],
}


def palette_count(image, palette, tolerance=5):
    return sum(count for count, pixel in image.getcolors(image.width * image.height)
               if any(max(abs(value - target) for value, target in zip(pixel, color)) <= tolerance
                      for color in palette))


def rendered_art(name, overview=False, courier=True):
    image = helpers.picture(name)
    world = image.crop((0, 150, 1070, 710))
    counts = {key: palette_count(world, palette) for key, palette in PALETTES.items()}
    sky = image.crop((0, 160, 1050, 410))
    counts["sky_blue_pixels"] = sum(90 < r < 235 and 125 < g < 245 and 140 < b < 245 and b > r
                                    for r, g, b in sky.get_flattened_data())
    if counts["sky_blue_pixels"] < 10000 or counts["grass"] < 15 or counts["rock"] < 100:
        raise RuntimeError("Actual plains sky/grass/rock did not render: " + str(counts))
    if overview:
        grass_rows = {index // world.width for index, pixel in enumerate(world.get_flattened_data())
                      if any(max(abs(value - target) for value, target in zip(pixel, color)) <= 5
                             for color in PALETTES["grass"])}
        counts["grass_vertical_span_px"] = max(grass_rows) - min(grass_rows) if grass_rows else 0
        if counts["grass_vertical_span_px"] < 90:
            raise RuntimeError("Artistic overview unexpectedly lost its substantial vertical course: " + str(counts))
    if courier and not overview and (counts["courier_cream"] < 5 or counts["courier_scarf"] < 2):
        raise RuntimeError("Actual original courier artwork did not render: " + str(counts))
    return counts


def palette_mask(name, palette):
    image = helpers.picture(name).crop((0, 150, 1280, 710))
    matching = {pixel for count, pixel in image.getcolors(image.width * image.height)
                if any(max(abs(value - target) for value, target in zip(pixel, color)) <= 5
                       for color in palette)}
    return bytes(pixel in matching for pixel in image.get_flattened_data())


async def main(url):
    FOLDER.mkdir(parents=True, exist_ok=True)
    checks, logs, probes, progress = [], [], {}, {}
    dynamics = {}
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(
            executable_path=shutil.which("chromium") or shutil.which("chromium-browser"),
            headless=True, args=["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"], timeout=30000)
        try:
            context = await browser.new_context(viewport={"width": 1280, "height": 720}, is_mobile=True, has_touch=True)
            page = await context.new_page()
            page.on("console", lambda message: logs.append(message.text))
            page.on("pageerror", lambda error: logs.append("PAGE ERROR: " + str(error)))
            await page.goto(url, wait_until="networkidle", timeout=45000)
            await page.wait_for_timeout(700)
            build_id = await page.locator("#playtest-version").get_attribute("data-build-id")
            client = await context.new_cdp_session(page)

            async def capture(name):
                await page.screenshot(path=str(FOLDER / (name + ".png")))

            async def leave(name):
                await page.touchscreen.tap(1220, 35)
                await page.wait_for_timeout(150)
                await capture(name + "-pause")
                await page.touchscreen.tap(*helpers.text_center(name + "-pause", "RETURN TO HOME"))
                await page.wait_for_timeout(100)
                await capture(name + "-confirm")
                await page.touchscreen.tap(*helpers.text_center(name + "-confirm", "LEAVE RUN"))
                await page.wait_for_timeout(300)

            async def walk(sign):
                await client.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": [{"x": 160, "y": 565, "id": 1}]})
                await client.send("Input.dispatchTouchEvent", {"type": "touchMove", "touchPoints": [{"x": 160 + 60 * sign, "y": 565, "id": 1}]})
                await page.wait_for_timeout(300)
                await client.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})

            await capture("home")
            await page.touchscreen.tap(*helpers.text_center("home", "10 rooms"))
            await page.wait_for_timeout(600)
            await capture("ten-room-first-plains")
            probes["fixed_room"] = rendered_art("ten-room-first-plains", courier=False)
            fixed_text = helpers.ocr("ten-room-first-plains", (0, 0, 1080, 150)).upper()
            if not re.search(r"ROOM\s+1\s+OF\s+10", fixed_text):
                raise RuntimeError("Actual first room of ten-room trial was not shown: " + fixed_text)
            await walk(1)
            await walk(1)
            await capture("ten-room-courier-clear")
            probes["fixed_courier_clear"] = rendered_art("ten-room-courier-clear")
            checks.append("Formal ten-room trial room 1 renders plains sky, grass/rock surfaces and original courier after real touch walking clears overlay")
            await leave("fixed")
            await capture("home-returned")
            await page.touchscreen.tap(*helpers.text_center("home-returned", "RANDOM STAGE"))
            await page.wait_for_timeout(600)

            for label, seed, sign in [("right", "rush-demo", 1), ("left", "left-proof-1", -1)]:
                await page.mouse.click(1125, 25)
                await page.keyboard.press("Control+A")
                await page.keyboard.type(seed, delay=30)
                await page.keyboard.press("Enter")
                await page.wait_for_timeout(500)
                await capture(label + "-entry")
                initial = helpers.rendered_progress(label + "-entry")
                if initial["route"] != 1 or initial["flow"] != label.upper():
                    raise RuntimeError("Visible seeded map direction mismatch: " + str(initial))
                probes[label + "_entry"] = rendered_art(label + "-entry", courier=False)
                await page.touchscreen.tap(1172, 202)
                await page.wait_for_timeout(200)
                await capture(label + "-overview")
                probes[label + "_overview"] = rendered_art(label + "-overview", overview=True)
                world_text = helpers.ocr(label + "-overview", (0, 145, 1070, 710)).upper()
                if any(word in world_text.split() for word in ["ENTRY", "EXIT", "SECTION"]):
                    raise RuntimeError("Authoring labels leaked into artistic map: " + world_text)
                if "JUMP" in helpers.ocr(label + "-overview", (895, 620, 1030, 710)).upper():
                    raise RuntimeError("Touch controls obstruct artistic overview")
                await page.wait_for_timeout(350)
                await capture(label + "-overview-frozen")
                if ImageChops.difference(helpers.picture(label + "-overview"), helpers.picture(label + "-overview-frozen")).getbbox():
                    raise RuntimeError("Artistic overview fails to freeze game clock/geometry")
                checks.append(label + " seeded full-map overview renders plains terrain without authoring labels/touch obstruction and freezes gameplay")
                if label == "right":
                    # Resource colors: moving_platform fill #535b56, bronze
                    # details #b99145, saw collision rim #d39964. Static props
                    # cancel out; pure courier idle motion cannot pass the mask.
                    mechanical_palette = [(83, 91, 86), (185, 145, 69), (211, 153, 100)]
                    before = palette_mask(label + "-overview", mechanical_palette)
                    grass_before = palette_mask(label + "-overview", PALETTES["grass"])
                    await page.touchscreen.tap(1172, 202)
                    await page.wait_for_timeout(650)
                    await page.touchscreen.tap(1172, 202)
                    await page.wait_for_timeout(200)
                    await capture("right-mechanisms-next-phase")
                    after = palette_mask("right-mechanisms-next-phase", mechanical_palette)
                    grass_after = palette_mask("right-mechanisms-next-phase", PALETTES["grass"])
                    changed = sum(a != b for a, b in zip(before, after))
                    if min(sum(before), sum(after)) < 15 or changed < 10:
                        raise RuntimeError("Actual artistic mechanical objects did not change visible position after unpaused gameplay")
                    if grass_before != grass_after:
                        raise RuntimeError("Static grass surface geometry changed while mechanisms advanced")
                    dynamics = {"mechanical_changed_pixels": changed, "initial_mechanical_pixels": sum(before),
                                "next_mechanical_pixels": sum(after), "static_grass_hash": hashlib.sha256(grass_before).hexdigest()}
                    checks.append("Artistic moving mechanisms visibly advance in real gameplay while static grass geometry remains unchanged")
                await page.touchscreen.tap(1172, 202)
                await page.wait_for_timeout(100)
                moved = initial
                for step in range(7):
                    await walk(sign)
                    await capture(label + "-touch-seam")
                    moved = helpers.rendered_progress(label + "-touch-seam")
                    if moved["route"] >= 2 and sign * (moved["world_x"] - initial["world_x"]) >= 220:
                        break
                if moved["route"] < 2 or sign * (moved["world_x"] - initial["world_x"]) < 220:
                    raise RuntimeError("Actual artistic touch movement did not cross seamless dock: " + str(moved))
                probes[label + "_courier_after_touch"] = rendered_art(label + "-touch-seam")
                progress[label] = {"seed": seed, "initial": initial, "after_touch": moved}
                checks.append(label + " original courier crosses first artistic grounded seam with real touch input")
            await leave("generated")
            await capture("home-final")
            checks.append("Confirmed leave of artistic generated preview returns to Home")
            if not any("Godot Engine v4.7.2" in entry for entry in logs):
                raise RuntimeError("Pinned engine did not start")
            if any(marker in entry for entry in logs for marker in ["SCRIPT ERROR:", "PAGE ERROR:", "Parse Error:", "SHADER ERROR:", "Shader compilation failed"]):
                raise RuntimeError("Actual browser engine errors: " + str(logs))
            checks.append("Pinned Godot Web renderer runs without parser, script or shader errors")
            report = {"checks": checks, "failed": 0, "url": page.url, "build_id": build_id,
                      "art_pixel_probes": probes, "touch_progress": progress, "mechanism_pixels": dynamics, "logs": logs,
                      "browser": "Chromium mobile touch emulation", "real_android": "unverified", "real_iphone_safari": "unverified",
                      "whole_generated_route_browser_traversal": "unverified; first grounded seam only"}
            (FOLDER / "browser-report.json").write_text(json.dumps(report, indent=2) + "\n")
            print(json.dumps(report))
        finally:
            await browser.close()


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8774/"
    server = None
    if target.startswith("http://127.0.0.1:8774"):
        server = subprocess.Popen([sys.executable, "-m", "http.server", "8774", "--bind", "127.0.0.1", "--directory", "build/web"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        asyncio.run(asyncio.wait_for(main(target), timeout=180))
    finally:
        if server:
            server.terminate()
            server.wait(timeout=5)
