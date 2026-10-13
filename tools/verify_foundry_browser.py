"""Visible Web GUI smoke; accepts local or deployed URL. No engine state writes.

Chromium is a renderer/GUI check, not actual phone or human fun acceptance.
"""
import asyncio
import json
import shutil
import sys
from pathlib import Path

from playwright.async_api import async_playwright

FOLDER = Path("build/verification/foundry-browser")


async def main():
    FOLDER.mkdir(parents=True, exist_ok=True)
    url = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8765"
    async with async_playwright() as p:
        browser = await p.chromium.launch(executable_path=shutil.which("chromium"), headless=True,
                                         args=["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
        page = await browser.new_page(viewport={"width": 1280, "height": 720}, accept_downloads=True)
        logs = []
        page.on("console", lambda message: logs.append(message.text))
        page.on("pageerror", lambda error: logs.append("PAGE ERROR: " + str(error)))
        await page.goto(url, wait_until="networkidle", timeout=60000)
        await page.wait_for_function("window.PLAYTEST_LOADING_DONE === true", timeout=60000)
        await page.wait_for_timeout(700)
        await page.mouse.click(640, 500)  # Title: DEVELOPMENT DEMOS
        await page.wait_for_timeout(400)
        await page.mouse.click(345, 615)  # LEVEL FOUNDRY
        await page.wait_for_timeout(1500)
        await page.screenshot(path=str(FOLDER / "loaded.png"))
        await page.keyboard.down("d")
        await page.wait_for_timeout(200)
        await page.keyboard.up("d")
        await page.keyboard.press("Space")
        await page.wait_for_timeout(300)
        await page.screenshot(path=str(FOLDER / "manual-input.png"))
        await page.mouse.click(106, 154)  # Fresh attempt + input replay
        await page.wait_for_timeout(9500)
        await page.screenshot(path=str(FOLDER / "replay-end.png"))
        await page.keyboard.press("Escape")
        await page.wait_for_timeout(250)
        await page.screenshot(path=str(FOLDER / "paused.png"))
        await page.keyboard.press("Escape")
        await page.wait_for_timeout(250)
        await page.mouse.click(365, 154)  # Keep
        async with page.expect_download(timeout=10000) as download_info:
            await page.mouse.click(298, 154)  # Export feedback
        download = await download_info.value
        target = FOLDER / "feedback-export.json"
        await download.save_as(str(target))
        feedback = json.loads(target.read_text())
        if not feedback or feedback[-1]["rating"] != "keep":
            raise RuntimeError("Visible rating/export did not produce actual feedback")
        await page.mouse.click(1060, 340)  # Ferry phrase
        await page.wait_for_timeout(700)
        await page.mouse.click(106, 154)
        await page.wait_for_timeout(17500)
        await page.screenshot(path=str(FOLDER / "ferry-replay-end.png"))
        errors = [line for line in logs if any(token in line for token in
                  ["SCRIPT ERROR", "Parse Error", "PAGE ERROR", "Failed to load script"])]
        report = {"url": url, "renderer": "Chromium WebGL software", "feedback_records": len(feedback),
                  "errors": errors, "failed": len(errors), "verification_scope": "visible_gui_inputs_screenshots_feedback_download",
                  "human_fun_and_mobile": "awaiting_device", "screenshots": [path.name for path in FOLDER.glob("*.png")]}
        (FOLDER / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        (FOLDER / "console.txt").write_text("\n".join(logs))
        await browser.close()
        if errors: raise RuntimeError("Foundry emitted Web script errors")
        print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    asyncio.run(main())
