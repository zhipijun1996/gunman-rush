"""Selected direction binding and short-prompt production boundaries, not artistic scoring."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import region_creative_direction as creative
import level_design
import production_loop


class CreativeTests(unittest.TestCase):
    def setUp(self):
        self.path = 'docs/creative_direction/thorn_forest.json'
        self.data = json.loads((creative.ROOT / self.path).read_text())

    def test_actual_recommendations_are_valid_but_never_player_or_runtime_acceptance(self):
        for path in ('windchime_plains', 'thorn_forest'):
            data, ref = creative.load_direction('docs/creative_direction/' + path + '.json', path)
            self.assertIn(data['acceptance'], {'professional_recommendation', 'user_confirmed'})
            if data['acceptance'] == 'professional_recommendation':
                self.assertEqual(data['user_acceptance'], 'unverified')
            else:
                self.assertEqual(data['user_acceptance'], 'direction_only_not_art_gameplay_or_device')
                self.assertIn('scope', data['user_evidence'])
            self.assertEqual(ref['sha256'], hashlib.sha256((creative.ROOT/ref['path']).read_bytes()).hexdigest())

    def test_historical_v2_bytes_keep_identity_and_reject_current_authority(self):
        published_registry = json.loads((creative.ROOT/'docs/creative_direction/archive/creative-v19/registry.json').read_bytes())
        expected = {
            'windchime_plains': '8f07e1c3d8fdd3553f7bf373075a52b2b900aac703b4789cead2cc5ebeeb0fa4',
            'thorn_forest': 'c79445e94ed41217ec326b0a928f1b6e723a754d66a8cc3eabcfd08e6c01b150',
        }
        for region, digest in expected.items():
            path = 'docs/creative_direction/archive/creative-v2/' + region + '.json'
            raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(), digest)
            self.assertEqual(json.loads(raw)['version'], 'creative-v2')
            with self.assertRaisesRegex(ValueError, 'Authority changed'):
                creative.load_direction(path, region)

        hud_previous = {'windchime_plains': '0ec669fcff9748b003008e700bf793e5174394e4626a6d6763d46b4953d36663', 'thorn_forest': 'ed1581a9c966e6fb0b20d0cce28bcde6d8eb5d16a2182a23c7716ad581d7b438'}
        for region,digest in hud_previous.items():
            path = 'docs/evidence/four_line_integration_20261023/direction-history/'+region+'-v10-before-hud-layout.json'
            raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            self.assertEqual(json.loads(raw)['version'],'creative-v10')
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.load_direction(path,region)

        foreground_previous = {'windchime_plains': '88b0b6fff129087952d4215d0a3e554171a8fd482234cacfb2e54a4359764ad3', 'thorn_forest': '3fe9f26a2eaba441f2fd7eee6900969cb6cbbb1a058c64b2aae732b2233b71ca'}
        for region,digest in foreground_previous.items():
            path = 'docs/evidence/four_line_integration_20261023/direction-history/'+region+'-v12-before-foreground-cpu.json'
            raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            self.assertEqual(json.loads(raw)['version'],'creative-v12')
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.load_direction(path,region)

        # Preserve exact previous direction and registry bytes, then refuse their
        # old binding under the new authority; never refresh historical SHA.
        previous = {
            'registry':'5d1e3bd9544d960f8dfc359682293f7729b02c7cc15d76b20115431e9e67b1d8',
            'windchime_plains':'ea67a36b0ce4a1606bca185c87879048493546d1602d8772b802f0d94ae93849',
            'thorn_forest':'4a61fefb33edffd734302eb32fa1a8dbe3b0f06f8212d3dc21923a92665860f8',
        }
        for name,digest in previous.items():
            path = 'docs/creative_direction/archive/creative-v17/'+name+'.json'
            old_raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(old_raw).hexdigest(),digest)
            if name == 'registry':
                current = creative.load_bible_registry()
                self.assertEqual({k:v for k,v in current.items() if k!='shared_style_authority'},
                                 {k:v for k,v in json.loads(old_raw).items() if k!='shared_style_authority'})
                continue
            old = json.loads(old_raw)
            self.assertEqual(old['version'],'creative-v17')
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.load_direction(path,name)
            current = json.loads((creative.ROOT/('docs/creative_direction/archive/creative-v19/'+name+'.json')).read_bytes())
            for key in old.keys()-{'version','region_bible','authority_sources','revision_impact'}:
                self.assertEqual(current[key],old[key])
            self.assertEqual(current['authority_sources'][:-2],old['authority_sources'])
            self.assertEqual(current['authority_sources'][-1],published_registry['shared_style_authority'])

        # The delivered V5 direction is a frozen original too. Keep its full
        # bytes and refusal, then append only the actual new style16 authority.
        delivered = {
            'registry':'706ebe31662101266b55bb832cfab6ccf4a9b7b00b6d36ee62d30a7d1ec788ec',
            'windchime_plains':'3fc390336ca7650562b287b9082279a7e647a9e89cc302170c088c9c015d5ca9',
            'thorn_forest':'d48147cf7ee5b6648cff51b579a6f776620263d30ef7528f5094bf27cc0fef20',
        }
        for name,digest in delivered.items():
            path = 'docs/creative_direction/archive/creative-v18/'+name+'.json'
            raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            old = json.loads(raw)
            if name == 'registry':
                current = creative.load_bible_registry()
                self.assertEqual({k:v for k,v in current.items() if k!='shared_style_authority'},
                                 {k:v for k,v in old.items() if k!='shared_style_authority'})
                continue
            self.assertEqual(old['version'],'creative-v18')
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.load_direction(path,name)
            current = json.loads((creative.ROOT/('docs/creative_direction/archive/creative-v19/'+name+'.json')).read_bytes())
            self.assertEqual(current['version'],'creative-v19')
            for key in old.keys()-{'version','region_bible','authority_sources','revision_impact'}:
                self.assertEqual(current[key],old[key])
            self.assertEqual(current['authority_sources'][:-1],old['authority_sources'])
            self.assertEqual(current['authority_sources'][-1],published_registry['shared_style_authority'])

        # The unpublished pre-art V19 candidate has its own exact identity;
        # same version text cannot make its older source binding current.
        pre_art = {
            'registry':'25992f7d338eef1135807bba9b55e34913d60802d86465ddbbfa878ee1cc198c',
            'windchime_plains':'f203d9d0cb4afdd1be85764134be6dcaa1d8047985f46347abd3e5897c6ace5c',
            'thorn_forest':'9f4b7ea857a83c8518191d3839009ba838d5fb9ef6bcb6a3ca01dc6e43b13f68',
        }
        for name,digest in pre_art.items():
            path = 'docs/evidence/item_art_01/source-bindings/pre-golden-r08/'+name+'.json'
            raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            old = json.loads(raw)
            if name == 'registry':
                current = creative.load_bible_registry()
                self.assertEqual({k:v for k,v in current.items() if k!='shared_style_authority'},
                                 {k:v for k,v in old.items() if k!='shared_style_authority'})
                continue
            self.assertEqual(old['version'],'creative-v19')
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.load_direction(path,name)
            current = json.loads((creative.ROOT/('docs/creative_direction/archive/creative-v19/'+name+'.json')).read_bytes())
            self.assertEqual(current['version'],'creative-v19')
            for key in old.keys()-{'region_bible','authority_sources','revision_impact'}:
                self.assertEqual(current[key],old[key])
            self.assertEqual(current['authority_sources'][:-1],old['authority_sources'][:-1])
            self.assertEqual(current['authority_sources'][-1],published_registry['shared_style_authority'])

        # The R08 golden V19 binding remains an exact historical candidate.
        # R09 uses the same version, with a separately reviewed source impact.
        r08 = {
            'bibles/registry':'17e3228cb0a155cf06f0db1676aca86c0b9dca90a086a87f2b86ac246e6bd238',
            'windchime_plains':'ab5c33c51a12d1763a6352c1b7c55e45e6952eec7ca14a33edba64d8b1b706e9',
            'thorn_forest':'d4239c72db564136a4033c08f05ff899cac9b765b2705b0e1a6757e681802a2b',
        }
        for name,digest in r08.items():
            path = 'docs/evidence/item_art_01/source-bindings/pre-expansion-r09/docs/creative_direction/'+name+'.json'
            raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            old = json.loads(raw)
            if name == 'bibles/registry':
                current = creative.load_bible_registry()
                self.assertEqual({k:v for k,v in current.items() if k!='shared_style_authority'},
                                 {k:v for k,v in old.items() if k!='shared_style_authority'})
                continue
            self.assertEqual(old['version'],'creative-v19')
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.load_direction(path,name)
            current = json.loads((creative.ROOT/('docs/creative_direction/archive/creative-v19/'+name+'.json')).read_bytes())
            self.assertEqual(current['version'],'creative-v19')
            for key in old.keys()-{'region_bible','authority_sources','revision_impact'}:
                self.assertEqual(current[key],old[key])
            self.assertEqual(current['authority_sources'][:-1],old['authority_sources'][:-1])
            self.assertEqual(current['authority_sources'][-1],published_registry['shared_style_authority'])

        # R10 changes only the three-body envelope metadata; retain R09's full
        # direction identity and reject its previous same-version binding.
        r09 = {
            'registry':'654ddbc7343fcfd956ee1f7f49bffd5635c8a6362b9ebefe338cc08f80522212',
            'windchime_plains':'17dd6ce7a53ec4cc4b1d7d17d24b4f8aa396f2356047fca6a662dea620ee4b67',
            'thorn_forest':'8ee67a31efc0ddeceb63544dbb745d0a29950c9da8b45c39a3285d215b92a907',
        }
        for name,digest in r09.items():
            path = 'docs/evidence/item_art_01/source-bindings/pre-envelope-r10/'+name+'.json'
            raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            old = json.loads(raw)
            if name == 'registry':
                current = creative.load_bible_registry()
                self.assertEqual({k:v for k,v in current.items() if k!='shared_style_authority'},
                                 {k:v for k,v in old.items() if k!='shared_style_authority'})
                continue
            self.assertEqual(old['version'],'creative-v19')
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.load_direction(path,name)
            current = json.loads((creative.ROOT/('docs/creative_direction/archive/creative-v19/'+name+'.json')).read_bytes())
            self.assertEqual(current['version'],'creative-v19')
            for key in old.keys()-{'region_bible','authority_sources','revision_impact'}:
                self.assertEqual(current[key],old[key])
            self.assertEqual(current['authority_sources'][:-1],old['authority_sources'][:-1])
            self.assertEqual(current['authority_sources'][-1],published_registry['shared_style_authority'])

        r10 = {
            'registry':'5756b99012a0ca430b3d0ee7705ffcf6a9080ea4c6b6432fc4f76e2648ec3e2a',
            'windchime_plains':'76f850ef4b56b3331bce30c997e6552428e92449cc56e6651c2026306999cac5',
            'thorn_forest':'b019e95a3ada136c2b2eb8be59d6307fadd877a1a04f7a304d30066aa5741d6b',
        }
        for name,digest in r10.items():
            path = 'docs/evidence/item_art_01/source-bindings/pre-legacy-cues-r11/'+name+'.json'
            raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            old = json.loads(raw)
            if name == 'registry':
                current = creative.load_bible_registry()
                self.assertEqual({k:v for k,v in current.items() if k!='shared_style_authority'},
                                 {k:v for k,v in old.items() if k!='shared_style_authority'})
                continue
            self.assertEqual(old['version'],'creative-v19')
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.load_direction(path,name)
            current = json.loads((creative.ROOT/('docs/creative_direction/archive/creative-v19/'+name+'.json')).read_bytes())
            self.assertEqual(current['version'],'creative-v19')
            for key in old.keys()-{'region_bible','authority_sources','revision_impact'}:
                self.assertEqual(current[key],old[key])
            self.assertEqual(current['authority_sources'][:-1],old['authority_sources'][:-1])
            self.assertEqual(current['authority_sources'][-1],published_registry['shared_style_authority'])

        # The superseded R11 draft had no claimed pure-check pass. Its exact
        # source identity still stays frozen and refused by the final binding.
        r11 = {
            'registry':'0d905ad097c0be7fd0f1868f20fd68524d6b151046c7be95f03beec1bc405699',
            'windchime_plains':'0aaf8181a0f9ca5b338739e355bb444ae20da0a0384d7a0843c40f831088af0e',
            'thorn_forest':'ca997ede2d07e5d0d2df01455706b4fa74d10168c1cc1783a496ea5f5568c81d',
        }
        for name,digest in r11.items():
            path = 'docs/evidence/item_art_01/source-bindings/pre-spend-proof-r12/'+name+'.json'
            raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            old = json.loads(raw)
            if name == 'registry':
                current = creative.load_bible_registry()
                self.assertEqual({k:v for k,v in current.items() if k!='shared_style_authority'},
                                 {k:v for k,v in old.items() if k!='shared_style_authority'})
                continue
            self.assertEqual(old['version'],'creative-v19')
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.load_direction(path,name)
            current = json.loads((creative.ROOT/('docs/creative_direction/archive/creative-v19/'+name+'.json')).read_bytes())
            self.assertEqual(current['version'],'creative-v19')
            for key in old.keys()-{'region_bible','authority_sources','revision_impact'}:
                self.assertEqual(current[key],old[key])
            self.assertEqual(current['authority_sources'][:-1],old['authority_sources'][:-1])
            self.assertEqual(current['authority_sources'][-1],published_registry['shared_style_authority'])

        r12 = {
            'registry':'79fe26430b3c03ddf3a08bee636ac4fd9e2f36805fbaeb62d5c3180898ab487e',
            'windchime_plains':'bfeb1faf2ada8b93481b24968bc5fd6c9ded39a2145dfde4eff7439ca0b4fbc3',
            'thorn_forest':'dd475ed3828e1b94067603b83f85e9e29379042c0240eef36ed445cae4e7d58c',
        }
        for name,digest in r12.items():
            path = 'docs/evidence/item_art_01/source-bindings/pre-main-audio-r13/'+name+'.json'
            raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            old = json.loads(raw)
            if name == 'registry':
                current = creative.load_bible_registry()
                self.assertEqual({k:v for k,v in current.items() if k!='shared_style_authority'},
                                 {k:v for k,v in old.items() if k!='shared_style_authority'})
                continue
            self.assertEqual(old['version'],'creative-v19')
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.load_direction(path,name)
            current = json.loads((creative.ROOT/('docs/creative_direction/archive/creative-v19/'+name+'.json')).read_bytes())
            self.assertEqual(current['version'],'creative-v19')
            for key in old.keys()-{'region_bible','authority_sources','revision_impact'}:
                self.assertEqual(current[key],old[key])
            self.assertEqual(current['authority_sources'][:-1],old['authority_sources'][:-1])
            self.assertEqual(current['authority_sources'][-1],published_registry['shared_style_authority'])

        # Published19 stays immutable and refused; only the new Home binding
        # appends an authority, retaining the complete original source prefix.
        published = {
            'registry':'ad269e01f7a0393375419802b400cf9ee1587bea8f32008b1fa6c0b9a2517583',
            'windchime_plains':'c8754c5a2e940da1553dc78cd411b2f05d8fb83a76620eed23a797107a80494a',
            'thorn_forest':'bd3c3f8dc13536c20510c23bc7b740c8464aef4aceebd9f0d8499a1e4ac39697',
        }
        for name,digest in published.items():
            path = 'docs/creative_direction/archive/creative-v19/'+name+'.json'
            raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            old = json.loads(raw)
            if name == 'registry':
                current = creative.load_bible_registry()
                self.assertEqual({k:v for k,v in current.items() if k!='shared_style_authority'},
                                 {k:v for k,v in old.items() if k!='shared_style_authority'})
                continue
            self.assertEqual(old['version'],'creative-v19')
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.load_direction(path,name)
            current = json.loads((creative.ROOT/('docs/creative_direction/archive/creative-v20/'+name+'.json')).read_bytes())
            self.assertEqual(current['version'],'creative-v20')
            for key in old.keys()-{'version','region_bible','authority_sources','revision_impact'}:
                self.assertEqual(current[key],old[key])
            self.assertEqual(current['authority_sources'][:-1],old['authority_sources'])
            self.assertEqual(current['authority_sources'][-1],json.loads((creative.ROOT/'docs/creative_direction/archive/creative-v20/registry.json').read_bytes())['shared_style_authority'])

        # Public Home20 bytes remain exact and stale under actual Chest21.
        published_home = {
            'registry':'210db55d8db4b01e6697074e13a3bfd596f5a2854df76a6de00ed7db67755d02',
            'windchime_plains':'e4d7c2527921b864bb3f8bbc4074ac9ba603f59661088aaa9978c6dcbf728673',
            'thorn_forest':'d74ef213098bb9984f5807eb1637c4d1a58b9474433d7e157363e6ed909b22e8',
        }
        for name,digest in published_home.items():
            path = 'docs/creative_direction/archive/creative-v20/'+name+'.json'
            raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            old = json.loads(raw)
            if name == 'registry':
                current = creative.load_bible_registry()
                self.assertEqual({k:v for k,v in current.items() if k!='shared_style_authority'},
                                 {k:v for k,v in old.items() if k!='shared_style_authority'})
                continue
            self.assertEqual(old['version'],'creative-v20')
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.load_direction(path,name)
            current = json.loads((creative.ROOT/('docs/creative_direction/archive/creative-v21/'+name+'.json')).read_bytes())
            self.assertEqual(current['version'],'creative-v21')
            for key in old.keys()-{'version','region_bible','authority_sources','revision_impact'}:
                self.assertEqual(current[key],old[key])
            self.assertEqual(current['authority_sources'][:-1],old['authority_sources'])
            self.assertEqual(current['authority_sources'][-1],json.loads((creative.ROOT/'docs/creative_direction/archive/creative-v21/registry.json').read_bytes())['shared_style_authority'])

        # First21/source18 pass remains exact and stale after the bounded
        # DemoApp input-resume correction within this unpublished candidate.
        pre_input = {
            'registry':'188ab18e9228e5c8e60db7667489fbdcef62b89c159d3d6c9b1adf93bb13072b',
            'windchime_plains':'3bc73b1c98bf3d8d8df693ed7c648cb7cdd8cbbc8d533a6284600aee99e2c7c0',
            'thorn_forest':'7be88d13236407b8f3bb47265def8b9efa91cdbab664be784e1007033be20133',
        }
        for name,digest in pre_input.items():
            path = 'docs/evidence/chest_art_01/source-bindings/before-reward-input-rebind/'+name+'.json'
            raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            old = json.loads(raw)
            if name == 'registry':
                current = creative.load_bible_registry()
                self.assertEqual({k:v for k,v in current.items() if k!='shared_style_authority'},
                                 {k:v for k,v in old.items() if k!='shared_style_authority'})
                continue
            self.assertEqual(old['version'],'creative-v21')
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.load_direction(path,name)
            current = json.loads((creative.ROOT/('docs/creative_direction/archive/creative-v21/'+name+'.json')).read_bytes())
            self.assertEqual(current['version'],'creative-v21')
            for key in old.keys()-{'region_bible','authority_sources','revision_impact'}:
                self.assertEqual(current[key],old[key])
            self.assertEqual(current['authority_sources'][:-1],old['authority_sources'][:-1])
            self.assertEqual(current['authority_sources'][-1],json.loads((creative.ROOT/'docs/creative_direction/archive/creative-v21/registry.json').read_bytes())['shared_style_authority'])

        # Published21 remains exact and stale;22 appends only the technical
        # style19 authority, retaining all direction/content/acceptance fields.
        published_chest = {
            'registry':'de601eecbbae88f1b426fa76f7c596723db676c6dd5e2585fbc1df2fb62ef44d',
            'windchime_plains':'316eda741874623405348efbdee263c2d300c9e155185b63b330dd3cf2815ab8',
            'thorn_forest':'1915808746fa49e6d302040578406e4650e78c41b64541d6b1c37973713de729',
        }
        for name,digest in published_chest.items():
            path = 'docs/creative_direction/archive/creative-v21/'+name+'.json'
            raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            old = json.loads(raw)
            if name == 'registry':
                current = creative.load_bible_registry()
                self.assertEqual({k:v for k,v in current.items() if k!='shared_style_authority'},
                                 {k:v for k,v in old.items() if k!='shared_style_authority'})
                continue
            self.assertEqual(old['version'],'creative-v21')
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.load_direction(path,name)
            current = json.loads((creative.ROOT/('docs/creative_direction/archive/merge-20261030-style19/program/'+name+'.json')).read_bytes())
            self.assertEqual(current['version'],'creative-v22')
            for key in old.keys()-{'version','region_bible','authority_sources','revision_impact'}:
                self.assertEqual(current[key],old[key])
            self.assertEqual(current['authority_sources'][:-1],old['authority_sources'])
            self.assertEqual(current['authority_sources'][-1],json.loads((creative.ROOT/'docs/creative_direction/archive/merge-20261030-style19/program/registry.json').read_bytes())['shared_style_authority'])

        # Bind01/source19 receipts are immutable after the two actual Boss
        # restore notifications. Same22 content/authority prefix is retained.
        bind01 = {
            'registry':'7624d24f07686121f7f7063785fbfdabba882d7b98b50063073b28e7608d9b02',
            'windchime_plains':'f4ccf685f0580bb6f6b44b76a1d5b813ec3dc2db7e75f3380bc1037b2de69298',
            'thorn_forest':'aa13e9a4322cc8b331b7b90cbc03ffd57298f2c22843aa8d541c2680b0f1c737',
        }
        for name,digest in bind01.items():
            path = 'docs/creative_direction/archive/creative-v22/before-boss-restore-notification/'+name+'.json'
            raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            old = json.loads(raw)
            if name == 'registry':
                current = creative.load_bible_registry()
                self.assertEqual({k:v for k,v in current.items() if k!='shared_style_authority'},
                                 {k:v for k,v in old.items() if k!='shared_style_authority'})
                continue
            self.assertEqual(old['version'],'creative-v22')
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.load_direction(path,name)
            current = json.loads((creative.ROOT/('docs/creative_direction/archive/merge-20261030-style19/program/'+name+'.json')).read_bytes())
            self.assertEqual(current['version'],'creative-v22')
            for key in old.keys()-{'region_bible','authority_sources','revision_impact'}:
                self.assertEqual(current[key],old[key])
            self.assertEqual(current['authority_sources'][:-1],old['authority_sources'][:-1])
            self.assertEqual(current['authority_sources'][-1],json.loads((creative.ROOT/'docs/creative_direction/archive/merge-20261030-style19/program/registry.json').read_bytes())['shared_style_authority'])

    def test_missing_theme_or_whole_screen_coverage_is_refused(self):
        for key in creative.COVERAGE:
            bad = copy.deepcopy(self.data); del bad[key]
            self.assertTrue(creative.validate_direction(bad), key)

    def test_candidate_comparison_cannot_be_empty_or_single_color_variant(self):
        self.data = json.loads((creative.ROOT/'docs/creative_direction/archive/creative-v3/thorn_forest.json').read_text())
        for mutate in ('single', 'duplicate', 'missing_comparison', 'unselected'):
            bad = copy.deepcopy(self.data)
            if mutate == 'single': bad['candidates'] = bad['candidates'][:1]
            if mutate == 'duplicate': bad['candidates'][1]['id'] = bad['candidates'][0]['id']
            if mutate == 'missing_comparison': del bad['candidates'][1]['ecology_boss']
            if mutate == 'unselected': bad['direction_id'] = 'uncompared'
            self.assertTrue(creative.validate_direction(bad), mutate)
        # Structural completeness does not prove real creative differences: independent review still required.

    def test_authority_changes_and_region_mismatch_fail_closed(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); (root/'authority.txt').write_text('old')
            data = json.loads((creative.ROOT/'docs/creative_direction/archive/creative-v3/thorn_forest.json').read_text())
            data['authority_sources'] = [{'path':'authority.txt','sha256':hashlib.sha256(b'old').hexdigest()}]
            (root/'direction.json').write_text(json.dumps(data))
            creative.load_direction('direction.json', 'thorn_forest', root)
            with self.assertRaisesRegex(ValueError, 'another region'):
                creative.load_direction('direction.json', 'windchime_plains', root)
            (root/'authority.txt').write_text('new')
            with self.assertRaisesRegex(ValueError, 'Authority changed'):
                creative.load_direction('direction.json', 'thorn_forest', root)

    def test_short_prompt_starts_creative_work_before_assets_or_terrain(self):
        mission = level_design.route_request('制作荆棘森林')
        production_loop.validate(mission)
        self.assertEqual(mission['phase'], 'production')
        self.assertEqual(len(mission['tasks']), 9)
        self.assertEqual(mission['region_bible']['bible_id'], 'thorn_forest_v2')
        self.assertNotIn('continuation', mission)
        self.assertEqual(mission['human_acceptance'], 'unverified')
        proposed = level_design.route_request('制作萤雾沼泽')
        self.assertEqual(proposed['phase'], 'preproduction')
        self.assertEqual(proposed['tasks'][0]['skills'], ['region-creative-director'])
        self.assertNotIn('scripts/', proposed['tasks'][0]['allowed_paths'])
        self.assertEqual(len(proposed['production_plan']), 9)

    def test_selected_direction_binds_every_specialist_and_retains_stage_gates(self):
        mission = level_design.route_request('制作荆棘森林', direction=self.path)
        production_loop.validate(mission)
        self.assertEqual(mission['phase'], 'production')
        for task in mission['tasks']:
            self.assertEqual(task['creative_direction']['region_id'], 'thorn_forest')
            self.assertEqual(task['creative_direction']['version'], 'creative-v23')
            self.assertEqual(task['feedback_context'], 'compact')
        self.assertEqual(mission['tasks'][-1]['completion'], 'content')
        self.assertIn('G2', mission['tasks'][-2]['required_gates'])
        self.assertFalse(mission['preparation']['production_boundary']['formal_opening_authorized'])

    def test_engineering_prototype_stays_explicit_and_does_not_claim_region(self):
        mission = level_design.route_request('制作荆棘森林', phase='prototype', direction=self.path)
        self.assertEqual(mission['phase'], 'prototype')
        self.assertIn('forest-current-slice', mission['tasks'][0]['checks'])
        self.assertNotIn('forest-h-slice', mission['tasks'][0]['checks'])
        self.assertEqual(mission['tasks'][0]['region_proof']['kind'], 'technical_sample')
        self.assertEqual(mission['tasks'][0]['region_proof']['allowed_capabilities'], ['H'])
        self.assertEqual(mission['tasks'][0]['required_gates'], ['G0','G1'])
        self.assertEqual(mission['tasks'][0]['region_proof']['scope'], 'prototype')

    def test_shared_source_inventory_keeps_original_extra_dependencies_and_detects_changes(self):
        import level_formal
        extras = ['tools/run_plains_experience_golden_tests.py',
                  'tools/run_plains_redesign_spatial_tests.py', 'tools/harness/profiles.json']
        before = level_formal.source_files()
        expected = dict(before)
        expected.update({name: hashlib.sha256((creative.ROOT/name).read_bytes()).hexdigest() for name in extras})
        self.assertEqual(level_formal.source_files(extra_paths=extras), expected)
        for name in extras:
            self.assertIn(name, level_formal.source_files(extra_paths=extras))
        with self.assertRaises(ValueError):
            level_formal.source_files(extra_paths=['../outside'])
        with self.assertRaises(FileNotFoundError):
            level_formal.source_files(extra_paths=['missing_producer.py'])

    def test_direction_cannot_bind_another_region_or_unregistered_request(self):
        for request in ('优化风铃平原', '制作未知地下河'):
            with self.assertRaises(ValueError):
                level_design.route_request(request, direction=self.path)



    def test_mobile_ui_creative22_preserves21_and_refuses_previous_pointer(self):
        archive = creative.ROOT/'docs/creative_direction/archive/creative-v21'
        digests = {'registry': 'de601eecbbae88f1b426fa76f7c596723db676c6dd5e2585fbc1df2fb62ef44d', 'windchime_plains': '316eda741874623405348efbdee263c2d300c9e155185b63b330dd3cf2815ab8', 'thorn_forest': '1915808746fa49e6d302040578406e4650e78c41b64541d6b1c37973713de729'}
        for name,digest in digests.items():
            raw = (archive/(name+'.json')).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            old = json.loads(raw)
            if name == 'registry':
                self.assertEqual({k:v for k,v in creative.load_bible_registry().items() if k!='shared_style_authority'},
                                 {k:v for k,v in old.items() if k!='shared_style_authority'})
                continue
            self.assertEqual(old['version'],'creative-v21')
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.load_direction('docs/creative_direction/archive/creative-v21/'+name+'.json',name)
            current = json.loads((creative.ROOT/('docs/creative_direction/archive/merge-20261030-style19/mobile/'+name+'.json')).read_bytes())
            self.assertEqual(current['version'],'creative-v22')
            for key in old.keys()-{'version','region_bible','authority_sources','revision_impact'}:
                self.assertEqual(current[key],old[key])
            self.assertEqual(current['authority_sources'][:-1],old['authority_sources'])
            self.assertEqual(current['authority_sources'][-1],json.loads((creative.ROOT/'docs/creative_direction/archive/merge-20261030-style19/mobile/registry.json').read_bytes())['shared_style_authority'])
            self.assertEqual(current['revision_impact']['task_id'],'MOBILE-UI-CLARITY-01')


    def test_merged23_preserves_both_parent22_content_and_rejects_both_bindings(self):
        root = creative.ROOT/'docs/creative_direction/archive/merge-20261030-style19'
        for region in ('windchime_plains','thorn_forest'):
            current,_ = creative.load_direction('docs/creative_direction/'+region+'.json',region)
            self.assertEqual(current['version'],'creative-v23')
            for parent in ('program','mobile'):
                path = root/parent/(region+'.json')
                old = json.loads(path.read_bytes())
                self.assertEqual(old['version'],'creative-v22')
                for key in old.keys()-{'version','region_bible','authority_sources','revision_impact'}:
                    self.assertEqual(current[key],old[key])
                with self.assertRaisesRegex(ValueError,'binding changed'):
                    creative.load_direction(str(path.relative_to(creative.ROOT)),region)
                self.assertIn(old['authority_sources'][-1],current['authority_sources'])
            program = json.loads((root/'program'/(region+'.json')).read_bytes())
            self.assertEqual(current['authority_sources'][:-2],program['authority_sources'])
            self.assertEqual(current['authority_sources'][-1],creative.load_bible_registry()['shared_style_authority'])
            self.assertEqual(current['revision_impact']['task_id'],'PLAINS-MOTION-LOOT-02')


if __name__ == '__main__':
    unittest.main()
