#!/usr/bin/env python3
"""Install the distributed APK and verify landscape gameplay and touch input on Android."""
import argparse
import io
import json
import subprocess
import time
from pathlib import Path
from PIL import Image, ImageChops, ImageStat

PACKAGE = "org.gunmanrush.review.plains"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--adb", default="adb")
    parser.add_argument("--serial")
    args = parser.parse_args()
    evidence = args.evidence
    evidence.mkdir(parents=True, exist_ok=True)
    adb = [args.adb] + (["-s", args.serial] if args.serial else [])

    def command(*parts):
        return subprocess.check_output(adb + [str(part) for part in parts], timeout=120)

    def shell(*parts):
        return command("shell", *parts).decode().strip()

    def screenshot(name):
        png = command("exec-out", "screencap", "-p")
        (evidence / (name + ".png")).write_bytes(png)
        return Image.open(io.BytesIO(png)).convert("RGB")

    def map_pixels(image):
        return sum(count for count, color in image.getcolors(image.width * image.height)
                   if max(abs(a-b) for a, b in zip(color, (81, 99, 90))) <= 2)

    model = shell("getprop", "ro.product.model")
    abi = shell("getprop", "ro.product.cpu.abilist")
    if "arm64-v8a" not in abi:
        raise RuntimeError("Device cannot install the locked ARM64 runtime: " + abi)
    print("Android", shell("getprop", "ro.build.version.release"), model, abi, flush=True)
    command("install", "-r", args.apk)
    shell("pm", "clear", PACKAGE)
    command("logcat", "-c")
    component = shell("cmd", "package", "resolve-activity", "--brief", PACKAGE).splitlines()[-1]
    if not component.startswith(PACKAGE + "/"):
        raise RuntimeError("Android launcher not found: " + component)
    print(shell("am", "start", "-W", "-n", component), flush=True)
    try:
        for _ in range(45):
            time.sleep(1)
            before = screenshot("01-spawn")
            if before.width > before.height and len(before.resize((96, 54)).getcolors(6000)) > 280:
                break
        else:
            raise RuntimeError("No landscape game frame after launch")
        time.sleep(3)
        before = screenshot("01-spawn")
        w, h = before.size

        def tap(x, y):
            shell("input", "tap", round(w*x), round(h*y))

        # The map toggle has fixed safe-area-relative bounds near the upper-left.
        for _ in range(3):
            tap(.124, .055)
            time.sleep(1)
            opened = screenshot("02-touch-map")
            if map_pixels(opened) > map_pixels(before) + w*h*.007:
                break
        else:
            raise RuntimeError("A real screen tap did not open the P01 map")
        tap(.124, .055)
        time.sleep(1)
        closed = screenshot("03-map-closed")
        if map_pixels(closed) >= map_pixels(opened) * .55:
            raise RuntimeError("Touch did not close the map")
        # A left-half press, drag and release goes through the floating movement stick.
        shell("input", "swipe", int(w*.12), int(h*.8), int(w*.40), int(h*.8), 1100)
        time.sleep(1)
        walked = screenshot("04-touch-walk")
        box = tuple(round(n * scale) for n, scale in zip((.20,.22,.82,.77),(w,h,w,h)))
        difference = sum(ImageStat.Stat(ImageChops.difference(closed.crop(box), walked.crop(box))).mean)/3
        if difference < 3:
            raise RuntimeError(f"Terrain/actor view did not move after the swipe ({difference:.2f})")
        if not shell("pidof", PACKAGE):
            raise RuntimeError("Game stopped after touch movement")
        receipt = {"model": model, "android": shell("getprop", "ro.build.version.release"),
                   "api": shell("getprop", "ro.build.version.sdk"), "abis": abi,
                   "emulator": shell("getprop", "ro.kernel.qemu") == "1",
                   "native_bridge": shell("getprop","ro.dalvik.vm.native.bridge"),
                   "window_pixels": [w,h], "map_pixels":map_pixels(opened),
                   "movement_image_difference":round(difference,2), "package":PACKAGE}
        print(json.dumps(receipt, indent=2),flush=True)
        (evidence / "device.json").write_text(json.dumps(receipt, indent=2)+"\n")
    finally:
        log = command("logcat", "-d", "-t", "4000")
        (evidence / "logcat.txt").write_bytes(log)
        errors = [line.decode(errors="replace") for line in log.splitlines()
                  if b"FATAL EXCEPTION" in line or (b"godot" in line.lower() and
                  (b"SCRIPT ERROR" in line or b"ERROR:" in line))]
        if errors:
            raise RuntimeError("\n".join(errors))


if __name__ == "__main__":
    main()
