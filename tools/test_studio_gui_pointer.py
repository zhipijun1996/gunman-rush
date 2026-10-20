"""Real screenshot border/OCR regression and strict clipped/ambiguous controls.

No browser or engine runs. Requires the same Pillow/NumPy/Tesseract toolchain as
studio_gui_pointer. Test-only derived crops never replace either raw PNG.
"""
import asyncio
import hashlib
import io
import json
import os
import subprocess
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


class WeaponPopupTests(unittest.TestCase):
    def image(self):
        return Image.open(FIXTURES / 'popup_W_green.png').convert('RGB')

    def parse(self, image):
        return helper._weapon_popup_from_pixels(image, 1, 197)

    def erase_marker(self, image, index):
        # Test-only removal of one actual radio, retaining its real item text.
        top = 212 + index * 29
        ImageDraw.Draw(image).rectangle((53, top, 66, top + 13),
                                        fill=image.getpixel((40, top)))

    def test_actual_green_popup_fifteen_observed_rows_and_selected_variants(self):
        image = self.image()
        popup = self.parse(image)
        # Exercise the unchanged actual HUD scan plus the real async helper,
        # with screenshot I/O supplied by this fixture; no browser is launched.
        class ScreenshotPage:
            viewport_size = {'width': 1280, 'height': 720}

            def __init__(self):
                self.mouse = self
                self.clicks = []

            async def screenshot(self):
                return (FIXTURES / 'popup_W_green.png').read_bytes()

            async def click(self, x, y):
                self.clicks.append((x, y))

            async def wait_for_timeout(self, _milliseconds):
                pass

        page = ScreenshotPage()
        self.assertEqual(asyncio.run(helper.weapon_row_y(page)), 179)
        self.assertEqual(asyncio.run(helper.open_weapon_picker(page)),
                         (popup['marker_x'], popup['rows']))
        self.assertEqual(popup['bounds'], (36, 191, 286, 654))
        self.assertEqual(popup['marker_x'], 59.5)
        self.assertEqual(popup['rows'], [218.5 + 29 * i for i in range(15)])
        # Exact actual selected/unselected pixel patches, not synthesized colors.
        selected = image.crop((53, 212, 67, 226))
        unselected = image.crop((53, 241, 67, 255))
        self.assertNotEqual(selected.tobytes(), unselected.tobytes())
        image.paste(unselected, (53, 212))
        image.paste(selected, (53, 618))
        self.assertEqual(self.parse(image)['rows'], popup['rows'])

    def test_fourteen_markers_rejected_even_with_all_fifteen_text_rows(self):
        image = self.image()
        self.erase_marker(image, 7)
        with self.assertRaisesRegex(AssertionError, 'not uniquely observed'):
            self.parse(image)

    def test_sixteen_markers_rejected_without_truncating_to_fifteen(self):
        image = self.image()
        icon = image.crop((53, 618, 67, 632))
        # Extend this test panel by one observed row gap, keeping a full border.
        draw = ImageDraw.Draw(image)
        draw.rectangle((36, 653, 285, 682), fill=image.getpixel((40, 640)))
        draw.line((36, 653, 36, 682), fill=(82, 96, 75))
        draw.line((285, 653, 285, 682), fill=(82, 96, 75))
        draw.line((36, 682, 285, 682), fill=(82, 96, 75))
        image.paste(icon, (53, 647))
        with self.assertRaisesRegex(AssertionError, 'not uniquely observed'):
            self.parse(image)

    def test_duplicate_complete_popups_rejected(self):
        image = self.image()
        image.paste(image.crop((35, 190, 287, 655)), (400, 190))
        with self.assertRaisesRegex(AssertionError, '2 complete popup/column candidates'):
            self.parse(image)

    def test_partially_visible_popup_rejected(self):
        with self.assertRaisesRegex(AssertionError, 'not uniquely observed'):
            self.parse(self.image().crop((0, 0, 1280, 621)))

    def test_periodic_text_glyph_columns_do_not_substitute_for_radio_markers(self):
        image = self.image()
        # Lv./tier/Chinese labels still provide several real 15-row columns.
        for index in range(15):
            self.erase_marker(image, index)
        with self.assertRaisesRegex(AssertionError, 'not uniquely observed'):
            self.parse(image)

    def test_nonuniform_actual_marker_gaps_rejected(self):
        image = self.image()
        icon = image.crop((53, 415, 67, 429))
        self.erase_marker(image, 7)
        image.paste(icon, (53, 420))
        with self.assertRaisesRegex(AssertionError, 'not uniquely observed'):
            self.parse(image)


class MobileTitleTests(unittest.TestCase):
    def image(self):
        return Image.open(FIXTURES / 'title_P_mobile.png').convert('RGB')

    def locate(self, image, whole_tsv=''):
        pixels = io.BytesIO()
        image.save(pixels, format='PNG')
        observation = {}
        with tempfile.TemporaryDirectory() as directory:
            point = helper._studio_title_from_pixels(
                pixels.getvalue(), Path(directory), 'title', observation, whole_tsv)
        return point, observation

    def test_actual_mobile_wholeframe_missing_same_frame_roi_full_title(self):
        image = self.image()
        # Replay the unchanged original whole-frame OCR, not a synthesized miss.
        full = image.convert('L').resize((image.width * 3, image.height * 3))
        data = io.BytesIO()
        full.save(data, format='PNG')
        result = subprocess.run(
            ['tesseract', 'stdin', 'stdout', '--psm', '11', 'tsv'],
            input=data.getvalue(), capture_output=True, check=True, timeout=10,
            env={**os.environ, 'OMP_THREAD_LIMIT': '1'})
        tsv = result.stdout.decode()
        with self.assertRaises(helper.StudioMenuLabelMissing):
            helper._studio_label_box(tsv, 'DEVELOPMENT DEMOS / ALL ENTRIES', 3)
        point, observation = self.locate(image, tsv)
        self.assertEqual(point, (509.5, 262.0))
        matches = [row for row in observation['title_button_rois']
                   if row['result'] == 'complete_label']
        self.assertEqual(len(matches), 1)
        self.assertEqual(matches[0]['bounds'], (430, 250, 631, 274))
        self.assertEqual(observation['whole_frame_title'], 'missing')

    def test_fullframe_ambiguity_rejects_before_any_roi_inspection(self):
        rows = ExactLabelTests().tsv(['DEVELOPMENT DEMOS / ALL ENTRIES'] * 2)
        with tempfile.TemporaryDirectory() as directory:
            # Invalid image would fail differently if ambiguity attempted ROI.
            with self.assertRaisesRegex(AssertionError, 'found 2'):
                helper._studio_title_from_pixels(
                    b'not an image', Path(directory), 'title', {}, rows)

    def test_each_missing_fill_boundary_rejected_with_all_title_glyphs_retained(self):
        for edge, notch in {
                'left': (430, 258, 433, 265),
                'right': (627, 258, 630, 265),
                'top': (500, 250, 560, 252),
                'bottom': (500, 271, 560, 273)}.items():
            with self.subTest(edge=edge):
                image = self.image()
                # Notches avoid actual text (x437..582/y259..264). All words
                # remain visible; a missing straight boundary still forbids ROI.
                ImageDraw.Draw(image).rectangle(notch,
                                               fill=image.getpixel((631, 262)))
                with self.assertRaises(helper.StudioMenuLabelMissing):
                    self.locate(image)

    def test_image_clipped_through_title_button_rejected(self):
        with self.assertRaises(helper.StudioMenuLabelMissing):
            self.locate(self.image().crop((0, 0, 565, 390)))

    def test_two_complete_real_mobile_title_buttons_rejected(self):
        image = self.image()
        image.paste(image.crop((429, 249, 632, 275)), (429, 310))
        with self.assertRaisesRegex(AssertionError, 'found 2 complete button matches'):
            self.locate(image)

    def test_partial_phrase_and_full_phrase_with_real_glyph_suffix_rejected(self):
        image = self.image()
        partial = image.copy()
        ImageDraw.Draw(partial).rectangle((550, 258, 583, 266),
                                         fill=image.getpixel((440, 255)))
        suffix = image.copy()
        # Copy the actual ALL word into the same visible line after ENTRIES;
        # OCR must reject the resulting complete phrase plus extra word.
        suffix.paste(image.crop((534, 259, 548, 265)), (591, 259))
        for name, control in [('partial', partial), ('extra_ALL', suffix)]:
            with self.subTest(control=name):
                with self.assertRaises(helper.StudioMenuLabelMissing):
                    self.locate(control)


if __name__ == '__main__':
    unittest.main(verbosity=2)
