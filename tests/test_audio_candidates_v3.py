"""V3 source, playback and DSP falsification checks; never signs hearing quality."""
import copy,importlib.util,json,shutil,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('audio_v3',ROOT/'tools/audio_candidates_v3.py');audio=importlib.util.module_from_spec(spec);spec.loader.exec_module(audio)

class V3CandidateGuards(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='v3-test-');self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        for name in ['assets/audio/director_v3','config/audio_director/v3']:shutil.copytree(ROOT/name,self.root/name)
        tool=self.root/'tools/audio_candidates_v3.py';tool.parent.mkdir();shutil.copyfile(audio.TOOL,tool)
        for key,value in [('ROOT',self.root),('CONFIG',self.root/'config/audio_director/v3'),('DEST',self.root/'assets/audio/director_v3'),('TOOL',tool)]:
            p=patch.object(audio,key,value);p.start();self.addCleanup(p.stop)

    def test_current_42_cues_validate_with_real_source_rerender(self):audio.validate()

    def test_recipe_tool_registry_fingerprint_drift_rejected(self):
        for p in [audio.TOOL,audio.CONFIG/'recipes.json',audio.CONFIG/'sources.json']:
            with self.subTest(path=p.name):
                before=p.read_bytes();p.write_bytes(before+b'\n')
                with self.assertRaisesRegex(ValueError,'drift'):audio.validate()
                p.write_bytes(before)

    def test_retained_raw_source_drift_rejected(self):
        s=next(iter(audio.read(audio.CONFIG/'sources.json')['sources'].values()));p=audio.local(s['path']);p.write_bytes(p.read_bytes()+b'drift')
        with self.assertRaisesRegex(ValueError,'fingerprint'):audio.validate()

    def test_actual_playback_cannot_redirect_or_add_false_variants(self):
        p=audio.DEST/'manifest.json';before=p.read_bytes()
        for key,value in [('path','res://assets/audio/director_v2/hurt_a.wav'),('variants',['res://assets/audio/director_v2/hurt_a.wav']),('variants',[])]:
            j=json.loads(before);j['events'][0]['candidates'][0][key]=value;audio.write(p,j)
            with self.assertRaisesRegex(ValueError,'Playback'):audio.validate()
        p.write_bytes(before)

    def test_metadata_and_summary_cannot_claim_another_design(self):
        p=audio.DEST/'manifest.json';before=p.read_bytes()
        for key,value in [('profile','C'),('source_ids',['fake']),('duration',999),('sha256','0'*64),('variant_policy','three original Nintendo recordings')]:
            j=json.loads(before);j['events'][0]['candidates'][0][key]=value;audio.write(p,j)
            with self.assertRaises(ValueError):audio.validate()
        for key,value in [('profiles',{'A':'approved'}),('version','forged'),('runtime_default','A'),('reference_policy','Nintendo audio copied')]:
            j=json.loads(before);j[key]=value;audio.write(p,j)
            with self.assertRaises(ValueError):audio.validate()
        p.write_bytes(before)

    def test_dsp_trace_gain_filter_crop_and_processing_recomputed(self):
        p=audio.DEST/'manifest.json';before=p.read_bytes()
        for key,value in [('normalization_gain_db',999),('processing','pure sine synthesis')]:
            j=json.loads(before);j['events'][0]['candidates'][0]['renders'][0][key]=value;audio.write(p,j)
            with self.assertRaisesRegex(ValueError,'DSP trace'):audio.validate()
        for key,value in [('ffmpeg_filter','volume=999dB'),('start_frame',999),('pitch_semitones',24),('delay_seconds',9)]:
            j=json.loads(before);j['events'][0]['candidates'][0]['renders'][0]['layers'][0][key]=value;audio.write(p,j)
            with self.assertRaisesRegex(ValueError,'DSP trace'):audio.validate()
        p.write_bytes(before)

    def test_modified_runtime_audio_rejected(self):
        p=audio.DEST/'coin_a.wav';b=bytearray(p.read_bytes());b[-8]^=255;p.write_bytes(b)
        with self.assertRaisesRegex(ValueError,'output fingerprint'):audio.validate()

    def test_input_profiles_and_ids_must_match_runtime_routes(self):
        config=audio.read(audio.CONFIG/'recipes.json');sources=audio.read(audio.CONFIG/'sources.json')['sources']
        changed=copy.deepcopy(config);changed['events'][0]['candidates'][1]['id']='coin_unroutable'
        with self.assertRaisesRegex(ValueError,'runtime route'):audio.inputs(changed,sources)
        changed=copy.deepcopy(config);changed['events'][0]['candidates'][1]['profile']='A'
        with self.assertRaisesRegex(ValueError,'exactly once'):audio.inputs(changed,sources)
        changed=copy.deepcopy(config);changed['events'][0]['candidates'][1].update(id='coin_unroutable',profile='A')
        with self.assertRaisesRegex(ValueError,'exactly once'):audio.inputs(changed,sources)
        changed=copy.deepcopy(config);changed['events'][0]['candidates'][1]['id']=changed['events'][0]['candidates'][0]['id']
        with self.assertRaisesRegex(ValueError,'runtime route'):audio.inputs(changed,sources)

    def test_liquid_body_is_required_by_recipe_contract(self):
        config=audio.read(audio.CONFIG/'recipes.json');sources=audio.read(audio.CONFIG/'sources.json')['sources'];event=next(x for x in config['events'] if x['id']=='heal')
        event['candidates'][0]['layers']=[copy.deepcopy(config['events'][0]['candidates'][0]['layers'][0])]
        with self.assertRaisesRegex(ValueError,'liquid'):audio.inputs(config,sources)

if __name__=='__main__':unittest.main()
