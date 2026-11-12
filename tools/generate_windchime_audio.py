#!/usr/bin/env python3
"""Reproducible original modal-synthesis cue; no samples or music assets."""
import math
import pathlib
import struct
import wave
import sys

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

def clock_resonance():
    """First regional clock: a low bronze strike with a long, non-looping tail."""
    duration = 6.0
    partials = ((174, .45, 2.8), (349, .36, 2.3), (471, .25, 1.7),
                (701, .18, 1.4), (964, .12, .9), (1303, .06, .5))
    samples = []
    for index in range(round(RATE * duration)):
        t = index / RATE
        envelope = min(1.0, t / .012) * min(1.0, (duration - t) / .4)
        value = sum(gain * math.exp(-t / decay) * math.sin(math.tau * freq * t)
                    for freq, gain, decay in partials)
        samples.append(envelope * value)
    gain = .75 / max(abs(v) for v in samples)
    output_path = ROOT / 'assets/plains_v07/audio/clock_resonance.wav'
    with wave.open(str(output_path), 'wb') as output:
        output.setnchannels(1); output.setsampwidth(2); output.setframerate(RATE)
        output.writeframes(struct.pack('<' + 'h' * len(samples),
                                       *(round(v * gain * 32767) for v in samples)))
    print(f'Original regional clock: {len(samples)} samples, {RATE} Hz, peak -2.5 dBFS')

if __name__ == '__main__':
    clock_resonance() if '--clock' in sys.argv else main()
