"""Edit one actual CC0 electronic timer beep; never synthesize a replacement tone.

Uses the explicitly retained Freesound HQ MP3 preview, not the login-only original
WAV. The mine's accepted entity age remains the only live cadence source.
"""
from pathlib import Path
import array, hashlib, json, math, subprocess, wave
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/player_presentation_01/mine_beep_v3'
SOURCE = OUT / 'sources/electronic-timer-536420-hq.mp3'
SOURCE_SHA = 'f86391668ac41cf57423131f73545a90635dc259b9c1bca8a5ce44dc59bb45a3'

def main():
    source_bytes = SOURCE.read_bytes()
    digest = hashlib.sha256(source_bytes).hexdigest()
    assert digest == SOURCE_SHA, 'Retained upstream bytes changed; review new source before editing'
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(SOURCE), '-f', 'f32le', '-ac', '1', '-ar', '48000', 'pipe:1'])
    samples = array.array('f'); samples.frombytes(raw)
    # First physical beep occupies ~.050-.120s. Retain onset/decay margins,
    # original pitch and timbre; no random pitch, room reverb or new oscillator.
    begin, end = 2160, 6240  # .045-.130 seconds at48k
    pulse = [float(v) for v in samples[begin:end]]
    fade = 144  #3ms click guard at both retained edges
    for i in range(fade):
        gain = .5-.5*math.cos(math.pi*i/fade)
        pulse[i] *= gain
        pulse[-1-i] *= gain
    peak = max(abs(v) for v in pulse)
    pcm = array.array('h', [round(v*.6/peak*32767) for v in pulse])
    target = OUT/'timer_beep.wav'
    with wave.open(str(target),'wb') as output:
        output.setnchannels(1); output.setsampwidth(2); output.setframerate(48000); output.writeframes(pcm.tobytes())
    report = dict(content_version='mine-beep-v3', source=dict(title='Electronic Timer Beeping 4X', author='Rudmer_Rotteveel', page='https://freesound.org/people/Rudmer_Rotteveel/sounds/536420/', download='https://cdn.freesound.org/previews/536/536420_4921277-hq.mp3', format='Public HQ MP3 preview;not original login-only WAV', license='CC0-1.0', license_url='https://creativecommons.org/publicdomain/zero/1.0/', path=str(SOURCE.relative_to(ROOT)), sha256=digest), processing=dict(ffmpeg_version=subprocess.check_output(['ffmpeg','-version'],text=True).splitlines()[0], decode='48k mono float32', crop_frames=[begin,end], fade_frames=fade, normalize_peak=.6, pitch_shift=False, synthesized_oscillator=False), output=dict(path=str(target.relative_to(ROOT)), sha256=hashlib.sha256(target.read_bytes()).hexdigest(), frames=len(pcm), duration_seconds=len(pcm)/48000, channels=1, sample_rate=48000, pcm_bits=16, peak=max(abs(v) for v in pcm)/32767), cadence='Unchanged actual entity age/fuse;one85ms beep then silence;interval.95->.12sec;no baked countdown or gameplay timer')
    (OUT/'provenance.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
if __name__=='__main__':main()
