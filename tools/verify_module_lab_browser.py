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


def player_center(image):
    points = [
        x
        for y in range(560, 604)
        for x in range(350)
        if 169 < image.getpixel((x, y))[0] < 196
        and 204 < image.getpixel((x, y))[1] < 230
        and 214 < image.getpixel((x, y))[2] < 240
    ]
    if len(points) < 300:
        raise RuntimeError("Actual module-lab player body was not rendered")
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

            async def move_right():
                await client.send("Input.dispatchTouchEvent", {
                    "type": "touchStart", "touchPoints": [{"x": 160, "y": 565, "id": 1}]
                })
                await client.send("Input.dispatchTouchEvent", {
                    "type": "touchMove", "touchPoints": [{"x": 220, "y": 565, "id": 1}]
                })
                await page.wait_for_timeout(300)
                await client.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})

            await move_right()
            await capture("touch-move")
            moved_x = player_center(picture("touch-move"))
            if moved_x - initial_x < 50:
                raise RuntimeError("Actual touch movement did not move the module-lab player")
            checks.append("Actual touch joystick moves the player")

            for name, x in [("stepped-crossing", 270), ("descending", 438), ("recoil-shaft", 606), ("timed-gallery", 774), ("moving-transfer", 942)]:
                await page.touchscreen.tap(x, 184)
                await page.wait_for_timeout(450)
                await capture(name)
            geometry_hashes = {
                name: hashlib.sha256(picture(name).crop((0, 270, 1280, 520)).tobytes()).hexdigest()
                for name in ["safe-hub", "stepped-crossing", "descending", "recoil-shaft", "timed-gallery", "moving-transfer"]
            }
            if len(set(geometry_hashes.values())) != 6:
                raise RuntimeError("Six module selections did not render distinct authored geometry")
            checks.append("All six authored layouts render distinct actual scene geometry")

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

            await page.touchscreen.tap(102, 184)
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
                "player_x": {"initial": initial_x, "touch_move": moved_x, "retry": retry_x},
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
        asyncio.run(asyncio.wait_for(main(target), timeout=90))
    finally:
        if server:
            server.terminate()
            server.wait(timeout=5)
