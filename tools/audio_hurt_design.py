#!/usr/bin/env python3
"""Reproducible CC0 fracture/body/air damage candidates; no commercial samples."""
from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path
import shutil
import tempfile

import audio_candidates_v3 as dsp

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / 'config/audio_director/feedback_06'
DEST = ROOT / 'assets/audio/feedback_06'
VERSION = 'audio-feedback-06-v1'


def local(name):
    path = ROOT / name.removeprefix('res://')
    if not path.resolve().is_relative_to(ROOT) or path.is_symlink():
        raise ValueError('Source path escapes repository')
    return path


def bindings():
    return {key: dsp.digest(path) for key, path in {
        'recipes_sha256': CONFIG / 'recipes.json', 'sources_sha256': CONFIG / 'sources.json',
        'pipeline_sha256': Path(__file__), 'processor_sha256': ROOT / 'tools/audio_candidates_v3.py'
    }.items()}


def inputs():
    recipe = dsp.read(CONFIG / 'recipes.json')
    sources = dsp.read(CONFIG / 'sources.json')['sources']
    if recipe['version'] != VERSION or recipe['sample_rate'] != dsp.RATE or recipe['event'] != 'hurt':
        raise ValueError('Unexpected damage recipe identity')
    if [c['id'] for c in recipe['candidates']] != ['hurt_feedback_06_' + c for c in 'abc']:
        raise ValueError('Expected three independently named damage directions')
    for name, expected in recipe['locked_inputs'].items():
        if dsp.digest(local(name)) != expected:
            raise ValueError('Protected BGM/previous candidate/processor changed: ' + name)
    for sid, source in sources.items():
        if source['license'] != 'CC0-1.0' or source['commercial_use'] is not True or source['attribution_required'] is not False:
            raise ValueError('Unreviewed commercial terms: ' + sid)
        for key in ['author', 'original_filename', 'download_date', 'download_url', 'source_url', 'license_url', 'commercial_conditions']:
            if not source.get(key): raise ValueError('Missing source provenance: ' + key)
        for path_key, sha_key in [('path', 'sha256'), ('source_page_path', 'source_page_sha256'), ('license_path', 'license_sha256')]:
            if dsp.digest(local(source[path_key])) != source[sha_key]:
                raise ValueError('Source/license fingerprint drift: ' + sid)
        if local(source['path']).stat().st_size != source['bytes']:
            raise ValueError('Source size drift: ' + sid)
    for candidate in recipe['candidates']:
        if not 0.05 <= candidate['max_seconds'] <= 0.35 or not 1 <= len(candidate['layers']) <= 4:
            raise ValueError('Unbounded damage candidate')
        for layer in candidate['layers']:
            if layer['source'] not in sources or not 0 < layer['clip_seconds'] <= .5 or not 0 < layer['gain'] <= 1 or abs(layer['pitch_semitones']) > 12:
                raise ValueError('Invalid sampled layer')
            if not 0 <= layer['start_seconds'] < 4 or not 0 <= layer['delay_seconds'] <= .05 or not -36 <= layer['normalize_rms_dbfs'] <= -18 or not 0 <= layer['max_input_gain_db'] <= 12:
                raise ValueError('Invalid crop/normalization bounds')
    return recipe, sources


def render(candidate, recipe, sources, folder):
    # Equalize source-layer energy before authored weights: raw recordings have
    # very different recording levels. Retain the actual crop/filter measurements
    # and bounded adjustment, rather than assuming gain=.5 means equally audible.
    effective = copy.deepcopy(candidate)
    normalization = []
    for authored, layer in zip(candidate['layers'], effective['layers']):
        samples, _ = dsp.layer_pcm(layer, sources, recipe)
        measured = dsp.pcm_metrics(samples)
        if measured['rms_dbfs'] < -70: raise ValueError('Inaudible source crop')
        gain_db = min(layer['normalize_rms_dbfs'] - measured['rms_dbfs'],
                      layer['max_input_gain_db'], -3 - measured['peak_dbfs'])
        layer['gain'] = authored['gain'] * 10 ** (gain_db / 20)
        normalization.append({'source': layer['source'], 'crop_metrics': measured,
                              'adjustment_db': gain_db, 'authored_weight': authored['gain'],
                              'effective_gain': layer['gain']})
    path = folder / ('hurt_' + candidate['profile'].lower() + '.wav')
    event = {'max_seconds': candidate['max_seconds'], 'target_rms_dbfs': recipe['target_rms_dbfs']}
    actual = dsp.render(event, effective, sources, recipe, path)
    actual['path'] = 'res://assets/audio/feedback_06/' + path.name
    actual['source_layer_normalization'] = normalization
    return {'id': candidate['id'], 'profile': candidate['profile'], 'label': candidate['label'],
            'design': candidate['design'], 'version': VERSION, 'path': actual['path'],
            'variants': [actual['path']], 'renders': [actual],
            'source_ids': list(dict.fromkeys(l['source'] for l in candidate['layers'])),
            'subjective_status': 'awaiting-user', 'risks': candidate['risks']}


def derive(recipe, sources, folder):
    return {'schema_version': 1, 'version': VERSION, 'task': recipe['task'], **bindings(),
            'ffmpeg_version': dsp.version(), 'sample_rate': dsp.RATE,
            'peak_ceiling_dbfs': recipe['peak_ceiling_dbfs'], 'target_rms_dbfs': recipe['target_rms_dbfs'],
            'reference_policy': recipe['reference_policy'], 'sources': sources,
            'locked_inputs': recipe['locked_inputs'], 'subjective_status': 'awaiting-user',
            'runtime_default': 'development audition A, not user accepted',
            'events': [{'id': 'hurt', 'candidates': [render(c, recipe, sources, folder) for c in recipe['candidates']]}]}


def run(build=False):
    before = bindings()
    recipe, sources = inputs()
    temp_root = ROOT / 'build/audio_feedback_06'
    temp_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='sample-render-', dir=temp_root) as temp:
        folder = Path(temp)
        expected = derive(recipe, sources, folder)
        inputs()
        if bindings() != before: raise ValueError('Source changed during render')
        if build:
            DEST.mkdir(parents=True, exist_ok=True)
            for path in folder.glob('*.wav'): shutil.copyfile(path, DEST / path.name)
            dsp.write(DEST / 'manifest.json', expected)
        if dsp.read(DEST / 'manifest.json') != expected:
            raise ValueError('Candidate/processing/source manifest differs from real derivation')
        for candidate in expected['events'][0]['candidates']:
            row = candidate['renders'][0]
            if dsp.measure(local(row['path'])) != {k: row[k] for k in dsp.measure(local(row['path']))}:
                raise ValueError('Runtime WAV differs from derived bytes: ' + candidate['id'])
            if row['peak_dbfs'] > recipe['peak_ceiling_dbfs'] + .002 or not -40 < row['rms_dbfs'] < -18 or row['duration'] > .35:
                raise ValueError('Candidate has invalid level/duration')
    print('AUDIO_HURT_DESIGN_OK candidates=3 licensed_sources=6 old_audio_unchanged=true')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['build', 'validate'])
    run(parser.parse_args().command == 'build')


if __name__ == '__main__':
    main()
