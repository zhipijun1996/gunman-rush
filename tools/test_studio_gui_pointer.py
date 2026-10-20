"""Real screenshot border/OCR regression and strict clipped/ambiguous controls.

No browser or engine runs. Requires the same Pillow/NumPy/Tesseract toolchain as
studio_gui_pointer. Test-only derived crops never replace either raw PNG.
"""
import hashlib
import io
import json
from collections import Counter
from pathlib import Path
import tempfile
import unittest

from PIL import Image, ImageDraw
import studio_gui_pointer as helper

FIXTURES = Path(__file__).resolve().parents[1] / 'tests/fixtures/studio_gui_pointer'


class ScreenshotButtonTests(unittest.TestCase):
    def locate(self, image):
        pixels = io.BytesIO()
        image.save(pixels, format='PNG')
        observation = {}
        with tempfile.TemporaryDirectory() as directory:
            point = helper._studio_actions_from_pixels(
                pixels.getvalue(), Path(directory), 'test', observation)
        return point, observation

    def test_fixture_raw_bytes_match_original_provenance(self):
        for record in json.loads((FIXTURES / 'provenance.json').read_text())['files']:
            with self.subTest(fixture=record['fixture']):
                raw = (FIXTURES / record['fixture']).read_bytes()
                self.assertEqual(len(raw), record['bytes'])
                self.assertEqual(hashlib.sha256(raw).hexdigest(), record['sha256'])

    def test_real_U_rare_border_complete_label_and_narrow_glyph_bounds(self):
        image = Image.open(FIXTURES / 'menu_U_complete.png').convert('RGB')
        # This actual highlighted border is #84, outside the former top16.
        palette = [color for color, _ in Counter(image.getdata()).most_common()]
        self.assertGreater(palette.index(image.getpixel((254, 285))) + 1, 16)
        point, observation = self.locate(image)
        matches = [row for row in observation['button_rois']
                   if row['result'] == 'complete_label']
        self.assertEqual(len(matches), 1)
        self.assertEqual(tuple(matches[0]['bounds']), (252, 270, 441, 327))
        left, top, right, bottom = matches[0]['actual_glyph_bounds']
        self.assertTrue(left < point[0] < right and top < point[1] < bottom)
        self.assertLess(right - left, 100)  # Actual English glyph, not whole button.

    def test_real_M_clipped_actions_stays_rejected(self):
        image = Image.open(FIXTURES / 'menu_M_clipped.png').convert('RGB')
        with self.assertRaises(helper.StudioMenuLabelMissing):
            self.locate(image)

    def test_two_complete_real_buttons_are_ambiguous(self):
        raw = Image.open(FIXTURES / 'menu_U_complete.png').convert('RGB')
        crop = raw.crop((248, 266, 445, 331))
        image = Image.new('RGB', (640, 400), raw.getpixel((248, 266)))
        image.paste(crop, (10, 10))
        image.paste(crop, (240, 100))
        with self.assertRaisesRegex(AssertionError, 'found 2 complete button matches'):
            self.locate(image)

    def test_each_missing_border_edge_rejects_rectangle(self):
        # Proposing a color from two run directions does not authorize a crop.
        for edge in ('left', 'top', 'right', 'bottom'):
            with self.subTest(edge=edge):
                image = Image.new('RGB', (280, 120), (9, 3, 7))
                draw = ImageDraw.Draw(image)
                draw.rectangle((40, 30, 230, 85), outline=(130, 155, 119))
                lines = {'left': (40, 30, 40, 85), 'top': (40, 30, 230, 30),
                         'right': (230, 30, 230, 85), 'bottom': (40, 85, 230, 85)}
                draw.line(lines[edge], fill=(9, 3, 7), width=5)
                self.assertEqual(helper._studio_button_boxes(image), [])

    def test_long_runs_without_closed_border_rejected(self):
        image = Image.new('RGB', (300, 150), (9, 3, 7))
        draw = ImageDraw.Draw(image)
        draw.line((40, 30, 230, 30), fill=(130, 155, 119), width=1)
        draw.line((40, 30, 40, 100), fill=(130, 155, 119), width=1)
        self.assertEqual(helper._studio_button_boxes(image), [])


class ExactLabelTests(unittest.TestCase):
    def tsv(self, labels):
        header = 'level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n'
        return header + ''.join(
            f'5\t1\t{i}\t1\t1\t1\t20\t{i*30}\t90\t12\t95\t{label}\n'
            for i, label in enumerate(labels, 1))

    def test_complete_plain_and_bilingual_labels(self):
        self.assertEqual(helper._studio_label_box(self.tsv(['ACTIONS']), 'ACTIONS'),
                         (65, 36))
        for delimiter in ('/', '|'):
            with self.subTest(delimiter=delimiter):
                # Same real OCR row; complete English clause is a separate word.
                header = self.tsv([])
                prefix = f'5\t1\t1\t1\t1\t1\t0\t30\t19\t12\t95\t动作练习 {delimiter}\n'
                english = self.tsv(['ACTIONS']).splitlines(keepends=True)[1]
                self.assertEqual(helper._studio_label_box(
                    header + prefix + english, 'ACTIONS'), (65, 36))

    def test_clipped_suffix_substring_and_duplicate_labels_rejected(self):
        for text in ('ACTI', 'ACTION', 'ACTIONS2', 'MORE ACTIONS', '/ ACTIONS',
                     '动作 / ACTIONS / OTHER'):
            with self.subTest(text=text):
                with self.assertRaises(helper.StudioMenuLabelMissing):
                    helper._studio_label_box(self.tsv([text]), 'ACTIONS')
        with self.assertRaisesRegex(AssertionError, 'found 2'):
            helper._studio_label_box(self.tsv(['ACTIONS', 'ACTIONS']), 'ACTIONS')


if __name__ == '__main__':
    unittest.main(verbosity=2)
