"""Bounded Module Lab smoke using the actual Chromium Web renderer.

Run from the repository root with an optional deployed URL. The default starts
a temporary local build/web server on port 8771. Requires Playwright, Pillow,
and Chromium. Touch emulation is not Android/iPhone real-device acceptance.
"""
import asyncio
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

from PIL import Image, ImageChops
from playwright.async_api import async_playwright


FOLDER = Path("build/verification/module-lab-browser")


def picture(name):
    return Image.open(FOLDER / (name + ".png")).convert("RGB")


def player_center(image, right=350):
    points = [
        x
        for y in range(560, 604)
        for x in range(right)
        if 169 < image.getpixel((x, y))[0] < 196
        and 204 < image.getpixel((x, y))[1] < 230
        and 214 < image.getpixel((x, y))[2] < 240
    ]
    if len(points) < 300:
        raise RuntimeError("Actual module-lab player body was not rendered")
    return sum(points) / len(points)


def boss_center(image):
    points = [
        x for y in range(520, 601) for x in range(890, 1240)
        if 110 < image.getpixel((x, y))[0] < 126
        and 158 < image.getpixel((x, y))[1] < 179
        and 185 < image.getpixel((x, y))[2] < 205
    ]
    if len(points) < 1000:
        raise RuntimeError("Actual Boss body was not rendered in its core")
    return sum(points) / len(points)


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

            async def capture(name):
                await page.screenshot(path=str(FOLDER / (name + ".png")))

            await capture("home")
            await page.touchscreen.tap(334, 450)
            await page.wait_for_timeout(700)
            await capture("safe-hub")
            initial_x = player_center(picture("safe-hub"))
            if not 100 < initial_x < 140:
                raise RuntimeError("Home MODULE LAB entry did not instantiate the safe hub")
            checks.append("Home MODULE LAB enters the actual safe hub")

            client = await context.new_cdp_session(page)

            async def move_right(duration=300):
                await client.send("Input.dispatchTouchEvent", {
                    "type": "touchStart", "touchPoints": [{"x": 160, "y": 565, "id": 1}]
                })
                await client.send("Input.dispatchTouchEvent", {
                    "type": "touchMove", "touchPoints": [{"x": 220, "y": 565, "id": 1}]
                })
                await page.wait_for_timeout(duration)
                await client.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})

            await move_right()
            await capture("touch-move")
            moved_x = player_center(picture("touch-move"))
            if moved_x - initial_x < 50:
                raise RuntimeError("Actual touch movement did not move the module-lab player")
            checks.append("Actual touch joystick moves the player")

            for name, x in [("stepped-crossing", 211), ("descending", 339), ("recoil-shaft", 467), ("timed-gallery", 595), ("moving-transfer", 723), ("loop-courtyard", 851), ("boss-approach", 979)]:
                await page.touchscreen.tap(x, 184)
                await page.wait_for_timeout(450)
                await capture(name)
            geometry_hashes = {
                name: hashlib.sha256(picture(name).crop((0, 270, 1280, 520)).tobytes()).hexdigest()
                for name in ["safe-hub", "stepped-crossing", "descending", "recoil-shaft", "timed-gallery", "moving-transfer", "loop-courtyard", "boss-approach"]
            }
            if len(set(geometry_hashes.values())) != 8:
                raise RuntimeError("Eight module selections did not render distinct authored geometry")
            checks.append("All eight authored layouts render distinct actual scene geometry")

            # Boss activation is exercised by the real touch adapter, never by
            # teleporting the browser player or calling gameplay internals.
            boss_roi = (890, 510, 1240, 605)
            boss_hud_roi = (400, 330, 960, 358)
            await capture("boss-dormant-before")
            await page.wait_for_timeout(600)
            await capture("boss-dormant-after")
            if ImageChops.difference(
                picture("boss-dormant-before").crop(boss_roi),
                picture("boss-dormant-after").crop(boss_roi),
            ).getbbox():
                raise RuntimeError("Boss began moving before the player entered its core")
            dormant_hud = picture("boss-dormant-before").crop(boss_hud_roi)
            if sum(min(dormant_hud.getpixel((x, y))) > 180 for y in range(dormant_hud.height) for x in range(dormant_hud.width)) < 100:
                raise RuntimeError("Actual Boss practice HUD was not visibly rendered")
            checks.append("Boss and rendered practice HUD remain dormant while player stays in the buffer")
            await move_right(2450)
            await capture("boss-active")
            boss_player_x = player_center(picture("boss-active"), right=1020)
            # Software rendering under concurrent headless tests can advance
            # fewer physics ticks per wall second; observe actual position and
            # bound additional real-input holds instead of assuming a timer.
            for _ in range(4):
                if boss_player_x >= 890:
                    break
                await move_right(400)
                await capture("boss-active")
                boss_player_x = player_center(picture("boss-active"), right=1020)
            if boss_player_x < 890:
                raise RuntimeError("Actual touch walk did not enter the Boss core")
            await page.wait_for_timeout(250)
            await capture("boss-active-later")
            boss_active_x = boss_center(picture("boss-active"))
            boss_later_x = boss_center(picture("boss-active-later"))
            if abs(boss_active_x - boss_center(picture("boss-dormant-before"))) < 2:
                raise RuntimeError("Boss did not visibly activate after grounded core entry")
            if not ImageChops.difference(
                dormant_hud, picture("boss-active-later").crop(boss_hud_roi)
            ).getbbox():
                raise RuntimeError("Boss practice HUD did not change after encounter activation")
            checks.append("Actual touch walk enters the core and activates Boss movement and HUD")
            await page.touchscreen.tap(1220, 35)
            await page.wait_for_timeout(200)
            await capture("boss-paused")
            await page.wait_for_timeout(600)
            await capture("boss-paused-later")
            if ImageChops.difference(picture("boss-paused"), picture("boss-paused-later")).getbbox():
                raise RuntimeError("Boss encounter continued advancing under Pause")
            checks.append("Active Boss geometry, encounter HUD and game clock freeze under Pause")
            await page.touchscreen.tap(640, 205)
            await page.wait_for_timeout(100)
            await page.touchscreen.tap(1170, 184)
            await page.wait_for_timeout(450)
            await capture("boss-retried")
            if abs(player_center(picture("boss-retried")) - initial_x) > 2:
                raise RuntimeError("Boss Retry did not restore the player to its buffer entry")
            await page.wait_for_timeout(600)
            await capture("boss-retried-later")
            if ImageChops.difference(
                picture("boss-retried").crop(boss_roi),
                picture("boss-retried-later").crop(boss_roi),
            ).getbbox():
                raise RuntimeError("Boss Retry retained an active encounter")
            if ImageChops.difference(
                dormant_hud, picture("boss-retried-later").crop(boss_hud_roi)
            ).getbbox():
                raise RuntimeError("Boss Retry did not restore its dormant HP/gold HUD")
            checks.append("Explicit Boss Retry restores buffer entry and fresh dormant HP/gold HUD")

            await page.touchscreen.tap(723, 184)
            await page.wait_for_timeout(450)
            # Use a clear gameplay ROI: moving geometry must visibly advance,
            # then stop under the real pause menu, without relying on HUD time.
            await capture("moving-platform-before")
            await page.wait_for_timeout(600)
            await capture("moving-platform-after")
            moving_roi = (370, 520, 990, 610)
            if not ImageChops.difference(
                picture("moving-platform-before").crop(moving_roi),
                picture("moving-platform-after").crop(moving_roi),
            ).getbbox():
                raise RuntimeError("Actual moving platform did not visibly advance")
            checks.append("Moving-transfer platform visibly advances in gameplay")
            await page.touchscreen.tap(1220, 35)
            await page.wait_for_timeout(200)
            await capture("moving-paused")
            await page.wait_for_timeout(600)
            await capture("moving-paused-later")
            if ImageChops.difference(picture("moving-paused"), picture("moving-paused-later")).getbbox():
                raise RuntimeError("Dynamic module continued moving under Pause")
            checks.append("Dynamic rendered geometry and game clock freeze under Pause")
            await page.touchscreen.tap(640, 205)
            await page.wait_for_timeout(200)

            await page.touchscreen.tap(83, 184)
            await page.wait_for_timeout(400)
            await move_right()
            await capture("before-retry")
            await page.touchscreen.tap(1170, 184)
            await page.wait_for_timeout(450)
            await capture("after-retry")
            retry_x = player_center(picture("after-retry"))
            if player_center(picture("before-retry")) - retry_x < 50 or abs(retry_x - initial_x) > 2:
                raise RuntimeError("Explicit retry did not return the actual player to module entry")
            checks.append("Explicit Retry starts a fresh attempt at the safe entry")

            await page.touchscreen.tap(1220, 35)
            await page.wait_for_timeout(200)
            await capture("paused")
            await page.wait_for_timeout(750)
            await capture("paused-later")
            if ImageChops.difference(picture("paused"), picture("paused-later")).getbbox():
                raise RuntimeError("Paused module scene or clock changed beneath the visible menu")
            checks.append("Paused rendered scene and game-clock text remain frozen")
            await page.touchscreen.tap(640, 205)
            await page.wait_for_timeout(300)
            await capture("resumed")
            if abs(player_center(picture("resumed")) - initial_x) > 2:
                raise RuntimeError("Resume failed to reveal the preserved module player")
            checks.append("Resume returns to the preserved module scene")

            await page.touchscreen.tap(1220, 35)
            await page.wait_for_timeout(100)
            await page.touchscreen.tap(640, 445)
            await page.wait_for_timeout(100)
            await capture("confirm-home")
            await page.touchscreen.tap(640, 265)
            await page.wait_for_timeout(400)
            await capture("returned-home")
            if ImageChops.difference(picture("home"), picture("returned-home")).getbbox():
                raise RuntimeError("Leaving practice did not restore the unchanged Home menu")
            checks.append("Confirmed leave returns Home without changing its run/meta summary")

            if not any("Godot Engine v4.7.2" in entry for entry in logs):
                raise RuntimeError("The pinned Godot engine did not start")
            if any(marker in entry for entry in logs for marker in [
                "SCRIPT ERROR:", "PAGE ERROR:", "Parse Error:", "SHADER ERROR:", "Shader compilation failed"
            ]):
                raise RuntimeError("Browser engine error: " + str(logs))
            report = {
                "checks": checks, "url": page.url,
                "build_id": await page.locator("#playtest-version").get_attribute("data-build-id"),
                "geometry_hashes": geometry_hashes,
                "boss_x": {"active": boss_active_x, "later": boss_later_x},
                "player_x": {"initial": initial_x, "touch_move": moved_x, "retry": retry_x, "boss_core": boss_player_x},
                "logs": logs, "browser": "Chromium mobile touch emulation",
                "real_android": "unverified", "real_iphone_safari": "unverified",
            }
            (FOLDER / "browser-report.json").write_text(json.dumps(report, indent=2) + "\n")
            print(json.dumps(report))
        finally:
            await browser.close()


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8771/"
    server = None
    if target.startswith("http://127.0.0.1:8771"):
        server = subprocess.Popen(
            [sys.executable, "-m", "http.server", "8771", "--bind", "127.0.0.1", "--directory", "build/web"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    try:
        asyncio.run(asyncio.wait_for(main(target), timeout=120))
    finally:
        if server:
            server.terminate()
            server.wait(timeout=5)
