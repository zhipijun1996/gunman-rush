#!/usr/bin/env python3
"""Reproducible original modal-synthesis cue; no samples or music assets."""
import math
import pathlib
import struct
import wave

ROOT = pathlib.Path(__file__).resolve().parents[1]
TARGET = ROOT / 'assets/audio/windchime_open.wav'
RATE = 22050
DURATION = 0.85
PARTIALS = ((880, 1, 0.28), (1321, 0.42, 0.21), (2210, 0.22, 0.16), (3103, 0.10, 0.11))

def main():
    samples = []
    for index in range(round(RATE * DURATION)):
        t = index / RATE
        attack = min(1.0, t / 0.006)
        tail = min(1.0, (DURATION - t) / 0.08)
        value = sum(gain * math.exp(-t / decay) * math.sin(math.tau * freq * t) for freq, gain, decay in PARTIALS)
        samples.append(round(32767 * 0.24 * attack * tail * value))
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(TARGET), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
    print(f'Original bell cue: {len(samples)} samples, {RATE} Hz, {DURATION}s, PCM mono')

if __name__ == '__main__':
    main()
