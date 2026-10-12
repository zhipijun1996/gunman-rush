"""Original deterministic synthesis: short shot, armour ping, core chime, roar."""
import math
import struct
import wave
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1] / 'assets/audio'
RATE = 22050
CUES = {'plains_shot': (.10, [(180, .6, .025), (1800, .22, .018)]),
        'plains_armour': (.16, [(1900, .6, .035), (2789, .3, .025)]),
        'plains_core': (.40, [(660, .7, .18), (990, .3, .12), (1661, .2, .10)]),
        'windkeeper_roar': (.75, [(71, .6, .4), (103, .35, .3), (147, .2, .25)])}
def main():
    for name, (duration, partials) in CUES.items():
        values = []
        for i in range(round(RATE * duration)):
            t = i / RATE
            attack = min(1, t / .006)
            tail = min(1, (duration - t) / .035)
            sound = sum(g * math.exp(-t / d) * math.sin(math.tau * f * t) for f, g, d in partials)
            values.append(round(32767 * .32 * attack * tail * sound))
        with wave.open(str(ROOT / (name + '.wav')), 'wb') as out:
            out.setnchannels(1); out.setsampwidth(2); out.setframerate(RATE)
            out.writeframes(struct.pack('<' + 'h' * len(values), *values))
if __name__ == '__main__': main()
