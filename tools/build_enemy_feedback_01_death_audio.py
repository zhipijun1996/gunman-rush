#!/usr/bin/env python3
"""Build only ENEMY-FEEDBACK-01's short death sound from licensed impacts.

No game script, shared cue, existing audio, mixer or signal is modified.
The result is designed layered audio, not claimed to be a field recording.
"""
import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import subprocess
import sys
import wave

RATE = 48000
SECONDS = .36
SEED = 701013
VERSION = 'enemy-feedback-01-death-burst-v7'


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def decode(path, filters, commands):
    command = ['ffmpeg', '-v', 'error', '-i', str(path), '-af', filters,
               '-ar', str(RATE), '-ac', '1', '-f', 'f32le', 'pipe:1']
    commands.append(command)
    result = array.array('f')
    result.frombytes(subprocess.check_output(command, timeout=30))
    if sys.byteorder != 'little': result.byteswap()
    return list(result)


def unit_peak(samples):
    gain = 1.0 / max(1e-9, max(abs(value) for value in samples))
    return [value * gain for value in samples], gain


def band_noise(rng, count, low, high):
    # Original deterministic broadband source. No tonal oscillator or sample
    # library is involved. Two one-pole filters bound the breath/crack texture.
    low_alpha = 1 - math.exp(-2 * math.pi * high / RATE)
    high_alpha = math.exp(-2 * math.pi * low / RATE)
    lp = hp = previous = 0.0
    result = []
    for _ in range(count):
        raw = rng.uniform(-1.0, 1.0)
        lp += low_alpha * (raw - lp)
        hp = high_alpha * (hp + lp - previous)
        previous = lp
        result.append(hp)
    return result


def db(value): return 20 * math.log10(max(1e-12, value))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    repo = args.repo.resolve()
    output = (args.output or repo / 'assets/audio/enemy_feedback_01').resolve()
    target = repo / 'assets/audio/enemy_feedback_01'
    scratch = (repo / 'build').resolve()
    if output != target and scratch not in output.parents:
        raise ValueError('Output must be the allocated task audio directory or scratch audition directory')
    names = ['death_burst.wav', 'provenance.json', 'README.md']
    if any((output / name).exists() for name in names):
        raise ValueError('Refusing to overwrite existing audio/evidence')
    source_root = repo / 'assets/audio/kenney'
    ledger_path = source_root / 'sources.json'
    ledger = json.loads(ledger_path.read_text())
    commands, source_rows = [], {}
    for cue in ['impact', 'boss_impact', 'enemy_defeat']:
        source = source_root / (cue + '.ogg')
        actual = sha(source)
        if actual != ledger[cue]['sha256'] or ledger[cue]['license'] != 'CC0-1.0':
            raise ValueError('Source bytes/license mismatch: ' + cue)
        source_rows[cue] = {**ledger[cue], 'runtime_path': str(source.relative_to(repo)), 'verified_sha256': actual}
    # Short, dry source windows plus original non-tonal broadband texture. No
    # laser, confirmation, bell, phaser or retained ringing tail enters this mix.
    crack, crack_gain = unit_peak(decode(source_root / 'impact.ogg',
        'highpass=f=550,lowpass=f=6500,atrim=duration=0.085,afade=t=in:d=0.0004,afade=t=out:st=0.025:d=0.060', commands))
    thud, thud_gain = unit_peak(decode(source_root / 'enemy_defeat.ogg',
        'highpass=f=65,lowpass=f=950,atrim=duration=0.115,afade=t=in:d=0.0006,afade=t=out:st=0.030:d=0.085', commands))
    body, body_gain = unit_peak(decode(source_root / 'boss_impact.ogg',
        'highpass=f=75,lowpass=f=1800,atempo=1.25,atrim=duration=0.160,afade=t=in:d=0.0007,afade=t=out:st=0.035:d=0.125', commands))
    count = round(SECONDS * RATE)
    mixed = [0.0] * count
    def add(samples, gain, delay):
        offset = round(delay * RATE)
        for index, value in enumerate(samples[:max(0, count - offset)]): mixed[index + offset] += value * gain
    add(crack, .22, 0)
    add(thud, .60, .001)
    add(body, .25, .006)
    rng = random.Random(SEED)
    noise = band_noise(rng, count, 650, 6800)
    # One initial crack followed by a quickly thinning fragment texture.
    for index, value in enumerate(noise):
        t = index / RATE
        attack = min(1.0, t / .0005)
        envelope = .70 * math.exp(-t / .023) + (.11 * math.exp(-(t - .024) / .070) if t >= .024 else 0.0)
        mixed[index] += value * attack * envelope
    # Small dry fragment accents use the physical sample, not pitched pings.
    add(crack, .075, .049)
    add(crack, .035, .093)
    add(crack, .015, .147)
    # Mild saturating blend prevents sharp internal layer sums; final amplitude
    # is explicitly normalized to -1dBFS sample peak with no clipped samples.
    mixed = [math.tanh(value * 1.1) for value in mixed]
    for index in range(count):
        t = index / RATE
        mixed[index] *= min(1.0, t / .0005) * min(1.0, (SECONDS - t) / .035)
    mean = sum(mixed) / count
    # Remove offset with the same endpoint window to retain zero endpoints.
    for index in range(count):
        t = index / RATE
        mixed[index] -= mean * min(1.0, t / .001) * min(1.0, (SECONDS - t) / .035)
    target_peak = 10 ** (-1 / 20)
    normalization = target_peak / max(abs(value) for value in mixed)
    mixed = [value * normalization for value in mixed]
    mixed[0] = mixed[-1] = 0.0
    pcm = [round(value * 32767) for value in mixed]
    output.mkdir(parents=True, exist_ok=True)
    wave_path = output / names[0]
    with wave.open(str(wave_path), 'wb') as file:
        file.setnchannels(1); file.setsampwidth(2); file.setframerate(RATE)
        file.writeframes(struct.pack('<%dh' % count, *pcm))
    actual = [value / 32768 for value in pcm]
    rms = math.sqrt(sum(value * value for value in actual) / count)
    energy = [value * value for value in actual]
    total = sum(energy)
    cumulative = 0.0
    t95 = 0.0
    for index, value in enumerate(energy):
        cumulative += value
        if cumulative >= total * .95:
            t95 = index / RATE
            break
    metrics = {'sample_rate': RATE, 'channels': 1, 'pcm_bits': 16, 'duration_seconds': count / RATE,
        'sample_peak_dbfs': db(max(abs(value) for value in actual)), 'rms_dbfs': db(rms),
        'clipped_samples': sum(abs(value) >= 32767 for value in pcm),
        'nonfinite_samples': sum(not math.isfinite(value) for value in mixed),
        'dc_offset': sum(actual) / count, 'energy_95_percent_time_seconds': t95,
        'first_sample': pcm[0], 'last_sample': pcm[-1], 'bytes': wave_path.stat().st_size}
    try:
        import numpy as np
        x = np.asarray(actual)
        spectrum = abs(np.fft.rfft(x)) ** 2
        freq = np.fft.rfftfreq(len(x), 1 / RATE)
        spectrum_total = float(spectrum.sum())
        cdf = np.cumsum(spectrum) / spectrum_total
        metrics['spectral_energy_median_hz'] = float(freq[np.argmax(cdf >= .5)])
        metrics['spectral_energy_95_percent_hz'] = float(freq[np.argmax(cdf >= .95)])
        metrics['energy_fraction_600_7000_hz'] = float(spectrum[(freq >= 600) & (freq <= 7000)].sum() / spectrum_total)
        metrics['spectrum_note'] = 'Frequency-energy measurements describe the rendered samples; they do not certify perceived physicality or subjective quality.'
    except ImportError:
        metrics['spectrum_note'] = 'numpy unavailable; spectrum unmeasured'
    source_license = source_root / 'impact-sounds-LICENSE.txt'
    provenance = {'task': 'ENEMY-FEEDBACK-01', 'content_version': VERSION, 'asset': 'death_burst.wav',
        'asset_sha256': sha(wave_path), 'producer': 'task deterministic offline builder',
        'producer_script_sha256': sha(Path(__file__)),
        'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip(),
        'sources_ledger_sha256': sha(ledger_path), 'sources': source_rows,
        'original_license': {'path': str(source_license.relative_to(repo)), 'sha256': sha(source_license),
            'license': 'CC0-1.0', 'url': 'https://creativecommons.org/publicdomain/zero/1.0/'},
        'original_synthesis': {'kind': 'deterministic non-tonal broadband noise, Python random.Random uniform through one-pole high/low-pass filters',
            'seed': SEED, 'third_party_samples': False, 'oscillators': False,
            'rights': 'Project-original procedural texture; no externally generated audio or model output.'},
        'ffmpeg_commands': commands,
        'mix_recipe': {'physical_crack_gain': .22, 'soft_thud_gain': .60, 'heavy_body_gain': .25,
            'source_unit_peak_gains': {'impact': crack_gain, 'enemy_defeat': thud_gain, 'boss_impact': body_gain},
            'fragment_delays_seconds': [.049, .093, .147], 'fragment_gains': [.075, .035, .015],
            'normalization_gain': normalization, 'target_sample_peak_dbfs': -1.0, 'duration_seconds': SECONDS},
        'objective_measurements': metrics,
        'integration_boundary': 'Use only the existing accepted enemy_defeat trigger for the selected two task enemies. Do not add a second cue or replace all global enemies.',
        'subjective_listening': 'unverified; file metrics and provenance do not sign sound quality',
        'ffmpeg_version': subprocess.check_output(['ffmpeg', '-version'], text=True).splitlines()[0]}
    (output / names[1]).write_text(json.dumps(provenance, indent=2, ensure_ascii=False) + '\n')
    (output / names[2]).write_text('# ENEMY-FEEDBACK-01 death burst\n\n'
        'A short designed physical crack/thud/debris burst. Created for the selected task enemies only; use the existing accepted `enemy_defeat` trigger, once. '
        'No second cue, gameplay change, or global audio replacement is implied.\n\n'
        'Sources are unmodified inputs from Kenney Impact Sounds (CC0): `impactWood_light_000.ogg`, `impactWood_heavy_000.ogg`, '
        'and `impactSoft_medium_000.ogg`. Original license: `../kenney/impact-sounds-LICENSE.txt`; pack: https://kenney.nl/assets/impact-sounds ; '
        'license: https://creativecommons.org/publicdomain/zero/1.0/ . The derivative filters, source hashes, mixture and original deterministic broadband-noise texture are documented in `provenance.json`.\n\n'
        'No laser/phaser, confirmation sound, bell oscillator or sustained tonal tail was used. This is a designed sample, not a claim of an actual field-recorded explosion. '
        'Objective duration/peak/clipping checks passed when the builder exits successfully; user listening and device/mix acceptance remain unverified.\n')
    if metrics['clipped_samples'] or metrics['nonfinite_samples'] or metrics['duration_seconds'] > .4:
        raise RuntimeError('Objective sound guard failed; preserve the output')
    print(json.dumps({'output': str(output), 'sha256': provenance['asset_sha256'], 'metrics': metrics}, indent=2))


if __name__ == '__main__': main()
