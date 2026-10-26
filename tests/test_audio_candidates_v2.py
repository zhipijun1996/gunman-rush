"""Reject stale recipes, false provenance and corrupted V2 candidate output."""
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('audio_candidates_v2',ROOT/'tools/audio_candidates_v2.py')
audio=importlib.util.module_from_spec(spec);spec.loader.exec_module(audio)

class CandidateGuards(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='audio-v2-test-');self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        for relative in ['config/audio_director/v2','assets/audio/director_v2']:
            shutil.copytree(ROOT/relative,self.root/relative)
        tool=self.root/'tools/audio_candidates_v2.py';tool.parent.mkdir();shutil.copyfile(audio.TOOL,tool)
        self.stack=[]
        for key,value in [('ROOT',self.root),('CONFIG',self.root/'config/audio_director/v2'),('DEST',self.root/'assets/audio/director_v2'),('TOOL',tool)]:
            p=patch.object(audio,key,value);p.start();self.addCleanup(p.stop)

    def test_current_artifacts_validate(self):
        audio.validate()

    def test_recipe_registry_and_tool_drift_reject_before_partial_write(self):
        paths=[audio.CONFIG/'recipes.json',audio.CONFIG/'sources.json',audio.TOOL]
        original_manifest=(audio.DEST/'manifest.json').read_bytes()
        outputs={p.name:audio.digest(p) for p in audio.DEST.glob('*.wav')}
        for path in paths:
            with self.subTest(path=path.name):
                content=path.read_bytes();path.write_bytes(content+b'\n')
                with self.assertRaisesRegex(ValueError,'changed'):audio.validate()
                with self.assertRaisesRegex(ValueError,'changed'):audio.build('click')
                self.assertEqual(original_manifest,(audio.DEST/'manifest.json').read_bytes())
                self.assertEqual(outputs,{p.name:audio.digest(p) for p in audio.DEST.glob('*.wav')})
                path.write_bytes(content)

    def test_raw_recording_drift_is_rejected(self):
        registry=audio.read(audio.CONFIG/'sources.json')['sources'];source=next(iter(registry.values()))
        path=audio.source_path(source['path']);path.write_bytes(path.read_bytes()+b'drift')
        with self.assertRaisesRegex(ValueError,'Source fingerprint'):audio.validate()
        with self.assertRaisesRegex(ValueError,'Source fingerprint'):audio.build('click')

    def test_false_source_snapshot_rejected(self):
        p=audio.DEST/'manifest.json';j=audio.read(p);next(iter(j['sources'].values()))['author']='forged';audio.write(p,j)
        with self.assertRaisesRegex(ValueError,'snapshot'):audio.validate()

    def test_modified_runtime_wave_is_rejected(self):
        p=audio.DEST/'coin_a.wav';b=bytearray(p.read_bytes());b[-12]^=255;p.write_bytes(b)
        with self.assertRaisesRegex(ValueError,'Output fingerprint'):audio.validate()

    def test_duplicate_take_cannot_claim_variants(self):
        config=audio.read(audio.CONFIG/'recipes.json');registry=audio.read(audio.CONFIG/'sources.json')['sources']
        c=config['events'][0]['candidates'][0];c['sources'][1]=c['sources'][0]
        with self.assertRaisesRegex(ValueError,'actual takes'):audio.validate_inputs(config,registry)

    def test_runtime_playback_paths_cannot_redirect_to_old_or_reordered_audio(self):
        p=audio.DEST/'manifest.json';before=p.read_bytes()
        changes=[('path','res://assets/audio/director_candidates/hurt_a.wav'),
                 ('variants',['res://assets/audio/director_candidates/hurt_a.wav']*2),
                 ('variants',list(reversed(audio.read(p)['events'][0]['candidates'][0]['variants'])))]
        for key,value in changes:
            with self.subTest(key=key,value=value):
                j=json.loads(before);j['events'][0]['candidates'][0][key]=value;audio.write(p,j)
                with self.assertRaisesRegex(ValueError,'playback'):audio.validate()
        p.write_bytes(before)

    def test_profile_sources_summary_and_preservation_are_bound_to_recipes(self):
        p=audio.DEST/'manifest.json';before=p.read_bytes()
        candidate_changes=[('profile','C'),('source_ids',['ui/click4.wav','ui/click5.wav']),('sha256','0'*64),('duration',9.0),('raw_sources',['assets/audio/director_candidates/hurt_a.wav']*2)]
        for key,value in candidate_changes:
            with self.subTest(key=key):
                j=json.loads(before);j['events'][0]['candidates'][0][key]=value;audio.write(p,j)
                with self.assertRaises(ValueError):audio.validate()
        for key,value in [('profiles',{'A':'approved'}),('version','audio-director-forged'),('preserve_original_events',[]),('runtime_default','A')]:
            with self.subTest(key=key):
                j=json.loads(before);j[key]=value;audio.write(p,j)
                with self.assertRaises(ValueError):audio.validate()
        p.write_bytes(before)

    def test_clean_partial_build_keeps_all_54_bytes(self):
        before={p.name:audio.digest(p) for p in audio.DEST.glob('*.wav')}
        audio.build('click')
        after={p.name:audio.digest(p) for p in audio.DEST.glob('*.wav')}
        self.assertEqual(len(before),54);self.assertEqual(before,after)

if __name__=='__main__':unittest.main()
