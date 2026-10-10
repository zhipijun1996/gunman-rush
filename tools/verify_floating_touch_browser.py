"""Real browser three-finger gesture with neutral movement and bounded evidence.
Do not put a screenshot between Jump and aim release: software WebGL screenshot
readback can outlast an entire normal jump, changing the observed input sequence.
"""
import asyncio
import json
import re
import subprocess
import sys
from pathlib import Path
import verify_plains_polish_browser as base


async def probe(page, context, capture, report):
    # Observe browser input only. This does not call Godot or change game state.
    await page.evaluate("""() => {
      window.floatingTouchEvents = [];
      for (const kind of ['touchstart', 'touchmove', 'touchend', 'touchcancel']) {
        document.addEventListener(kind, event => {
          window.floatingTouchEvents.push({kind, time: performance.now(),
            changed: Array.from(event.changedTouches).map(t => ({id:t.identifier, x:t.clientX, y:t.clientY})),
            held: Array.from(event.touches).map(t => ({id:t.identifier, x:t.clientX, y:t.clientY}))});
        }, true);
      }
    }""")
    cdp = await context.new_cdp_session(page)
    left = {"x": 350, "y": 400, "id": 1}
    right = {"x": 880, "y": 380, "id": 2}
    await cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": [left, right]})
    left["x"] = 400
    right["y"] = 440
    await cdp.send("Input.dispatchTouchEvent", {"type": "touchMove", "touchPoints": [left, right]})
    # Brief movement demonstrates the left vector, then return to the exact
    # floating origin before Jump. There is no sustained walk off a platform.
    await page.wait_for_timeout(30)
    left["x"] = 350
    await cdp.send("Input.dispatchTouchEvent", {"type": "touchMove", "touchPoints": [left, right]})
    jump = {"x": 1208, "y": 606, "id": 3}
    await cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": [left, right, jump]})
    await page.wait_for_timeout(30)
    # Remove only the right finger; Jump and the neutral movement finger remain
    # held. For CDP touchEnd, nonempty touchPoints names contacts to END,
    # rather than contacts remaining on screen. Verify the resulting DOM events.
    # The actual independent contact release emits the projectile.
    await cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": [right]})
    await capture("floating-jump-shot")
    events = await page.evaluate("window.floatingTouchEvents")
    report["actual_floating_touch_events"] = events
    (base.FOLDER / "touch-events.json").write_text(json.dumps(events, indent=2) + "\n")
    third = next((e for e in events if e["kind"] == "touchstart" and any(t["id"] == 3 for t in e["changed"])), None)
    shot_release = next((e for e in events if e["kind"] == "touchend" and any(t["id"] == 2 for t in e["changed"])), None)
    if third is None or shot_release is None or {t["id"] for t in third["held"]} != {1, 2, 3} or {t["id"] for t in shot_release["held"]} != {1, 3}:
        raise RuntimeError("Browser did not preserve independent three-finger start/release identifiers")
    neutral = next((e for e in reversed(events[:events.index(third)]) if e["kind"] == "touchmove" and any(t["id"] == 1 and t["x"] == 350 for t in e["changed"])), None)
    if neutral is None:
        raise RuntimeError("Movement finger never returned to its floating origin before Jump")
    text = base.h.ocr("floating-jump-shot", (0, 0, 900, 200)).upper()
    report["actual_floating_touch_ocr"] = text
    if not re.search(r"AIR\s*SHOTS\s+1", text):
        raise RuntimeError("Neutral movement + third-finger Jump + independent aim release did not consume an airborne shot: " + text)
    report["checks"].append("Real browser neutral floating movement, third-finger JUMP and independent aim release consume an airborne shot; DOM confirms three separate contacts")
    await cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
    await page.wait_for_timeout(150)


if __name__ == "__main__":
    base.FOLDER = Path("build/verification/floating-touch-browser")
    base.h.FOLDER = base.FOLDER
    url = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8788/"
    server = None
    if len(sys.argv) == 1:
        server = subprocess.Popen([sys.executable, "-m", "http.server", "8788", "--bind", "127.0.0.1", "--directory", "build/web"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        asyncio.run(asyncio.wait_for(base.main(url, probe), timeout=240))
    finally:
        if server:
            server.terminate()
            server.wait(timeout=5)
