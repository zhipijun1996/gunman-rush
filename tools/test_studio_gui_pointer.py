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
        self.assertEqual(asyncio.run(helper.open_weapon_picker(page,historical_fixture=True)),
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


class MobileActionsTests(unittest.TestCase):
    def image(self):
        return Image.open(FIXTURES / 'actions_Q_mobile.png').convert('RGB')

    def locate(self, image):
        pixels = io.BytesIO()
        image.save(pixels, format='PNG')
        observation = {}
        with tempfile.TemporaryDirectory() as directory:
            point = helper._studio_actions_from_pixels(
                pixels.getvalue(), Path(directory), 'actions', observation)
        return point, observation

    def test_actual_mobile_closed_border_and_inner_full_english_clause(self):
        point, observation = self.locate(self.image())
        matches = [row for row in observation['button_rois']
                   if row['result'] == 'complete_label']
        self.assertEqual(len(matches), 1)
        match = matches[0]
        self.assertEqual(match['bounds'], (211, 145, 316, 178))
        self.assertIn('border_ocr_missing', match)
        self.assertEqual(match['inner_fill_bounds'], (214, 148, 313, 175))
        self.assertEqual(point, (286.1875, 163.0))
        left, top, right, bottom = match['actual_glyph_bounds']
        self.assertTrue(left < point[0] < right and top < point[1] < bottom)

    def test_missing_actual_mobile_colored_edges_do_not_get_inner_fallback(self):
        for edge, strip in {
                'left': (211, 145, 214, 178),
                'right': (311, 145, 315, 178),
                'top': (211, 145, 315, 148),
                'bottom': (211, 174, 315, 178)}.items():
            with self.subTest(edge=edge):
                image = self.image()
                ImageDraw.Draw(image).rectangle(strip,
                                               fill=image.getpixel((210, 160)))
                with self.assertRaises(helper.StudioMenuLabelMissing):
                    self.locate(image)

    def test_two_actual_mobile_actions_buttons_remain_ambiguous(self):
        image = self.image()
        image.paste(image.crop((210, 144, 317, 179)), (400, 340))
        with self.assertRaisesRegex(AssertionError, 'found 2 complete button matches'):
            self.locate(image)

    def test_partial_and_suffixed_mobile_english_words_rejected(self):
        image = self.image()
        partial = image.copy()
        ImageDraw.Draw(partial).rectangle((301, 160, 306, 165),
                                         fill=image.getpixel((270, 150)))
        suffix = image.copy()
        # Extra actual terminal S glyph inside the same complete visible button.
        suffix.paste(image.crop((301, 160, 306, 166)), (307, 160))
        for name, control in [('partial', partial), ('extra_S', suffix)]:
            with self.subTest(control=name):
                with self.assertRaises(helper.StudioMenuLabelMissing):
                    self.locate(control)


class MobilePopupTests(unittest.TestCase):
    # Actual component rectangles observed in the raw S screenshot, not rows
    # generated from a presumed pitch or target coordinates used by the helper.
    BOXES = [(104, 114, 113, 123), (104, 129, 113, 139),
             (104, 145, 113, 155), (104, 161, 113, 171),
             (104, 177, 113, 186), (104, 192, 113, 202),
             (104, 208, 113, 218), (104, 224, 113, 233),
             (104, 239, 113, 249), (104, 255, 113, 265),
             (104, 271, 113, 280), (104, 287, 113, 296),
             (104, 302, 113, 312), (104, 318, 113, 328),
             (104, 334, 113, 343)]

    def image(self):
        return Image.open(FIXTURES / 'popup_S_mobile.png').convert('RGB')

    def parse(self, image):
        return helper._weapon_popup_from_pixels(image, 390 / 720, 106)

    def erase(self, image, box):
        left, top, right, bottom = box
        for y in range(top, bottom):
            ImageDraw.Draw(image).line((left, y, right - 1, y),
                                      fill=image.getpixel((right, y)))

    def test_actual_fractional_popup_hover_selected_fifteen_real_markers(self):
        popup = self.parse(self.image())
        self.assertEqual(popup['marker_boxes'], self.BOXES)
        self.assertEqual(popup['marker_x'], 108.0)
        self.assertEqual(popup['rows'], [118.0, 133.5, 149.5, 165.5, 181.0,
                         196.5, 212.5, 228.0, 243.5, 259.5, 275.0,
                         291.0, 306.5, 322.5, 338.0])
        # Exercise the original async HUD/pointer helper against exact raw
        # screenshot I/O only; this is not a browser or accepted item-ID claim.
        class ScreenshotPage:
            viewport_size = {'width': 844, 'height': 390}

            def __init__(self):
                self.touchscreen = self

            async def screenshot(self):
                return (FIXTURES / 'popup_S_mobile.png').read_bytes()

            async def tap(self, _x, _y):
                pass

            async def wait_for_timeout(self, _milliseconds):
                pass

        page = ScreenshotPage()
        self.assertEqual(asyncio.run(helper.open_weapon_picker(page, True,historical_fixture=True)),
                         (popup['marker_x'], popup['rows']))

    def test_missing_selected_middle_or_all_radios_never_inferred_from_text(self):
        for name, boxes in [('selected', self.BOXES[:1]),
                            ('middle', self.BOXES[7:8]),
                            ('all', self.BOXES)]:
            with self.subTest(control=name):
                image = self.image()
                for box in boxes:
                    self.erase(image, box)
                with self.assertRaisesRegex(AssertionError, '0 complete popup/column'):
                    self.parse(image)

    def test_duplicate_mobile_popup_remains_ambiguous(self):
        image = self.image()
        image.paste(image.crop((94, 102, 231, 355)), (340, 102))
        with self.assertRaisesRegex(AssertionError, '2 complete popup/column'):
            self.parse(image)

    def test_clipped_panel_and_each_missing_fill_boundary_rejected(self):
        image = self.image()
        for name, control in [('bottom_crop', image.crop((0, 0, 844, 340))),
                              ('right_crop', image.crop((0, 0, 225, 390)))]:
            with self.subTest(control=name):
                with self.assertRaises(AssertionError):
                    self.parse(control)
        for edge, notch in {
                'top': (145, 105, 190, 107),
                'bottom': (145, 350, 190, 352),
                'left': (97, 210, 100, 250),
                'right': (226, 210, 228, 250)}.items():
            with self.subTest(edge=edge):
                control = image.copy()
                # Keep all15 marker boxes intact while opening this fill edge.
                ImageDraw.Draw(control).rectangle(notch, fill=(1, 2, 3))
                with self.assertRaises(AssertionError):
                    self.parse(control)

    def test_solid_and_flat_chamfered_squares_cannot_use_rounding_exception(self):
        for chamfered in (False, True):
            with self.subTest(chamfered=chamfered):
                image = self.image()
                draw = ImageDraw.Draw(image)
                for box in self.BOXES:
                    self.erase(image, box)
                    left, top, right, bottom = box
                    size = min(right - left, bottom - top)
                    draw.rectangle((left, top, left + size - 1, top + size - 1),
                                   fill=(100, 100, 100))
                    if chamfered:
                        for x, y in [(left, top), (left + size - 1, top),
                                     (left, top + size - 1),
                                     (left + size - 1, top + size - 1)]:
                            draw.point((x, y), fill=image.getpixel((right, y)))
                with self.assertRaises(AssertionError):
                    self.parse(image)


class MobilePopupPhaseTests(unittest.TestCase):
    # Actual rectangles from original T click-consumer failure PNG. The second
    # unselected circle has a fractional reflection center, not a missing row.
    BOXES = [(104, 129, 113, 138), (104, 144, 113, 154),
             (104, 160, 113, 170), (104, 176, 113, 186),
             (104, 192, 113, 201), (104, 207, 113, 217),
             (104, 223, 113, 233), (104, 239, 113, 248),
             (104, 254, 113, 264), (104, 270, 113, 280),
             (104, 286, 113, 295), (104, 302, 113, 311),
             (104, 317, 113, 327), (104, 333, 113, 343),
             (104, 349, 113, 358)]

    def image(self):
        return Image.open(FIXTURES / 'popup_T_mobile_selected9.png').convert('RGB')

    def parse(self, image):
        return helper._weapon_popup_from_pixels(image, 390 / 720, 106)

    def erase(self, image, box):
        MobilePopupTests.erase(self, image, box)

    def test_actual_T_half_pixel_circle_and_fifteen_complete_observed_boxes(self):
        import numpy as np
        image = self.image()
        silhouette = np.any(np.asarray(image.crop(self.BOXES[1])) !=
                            np.asarray(image.crop((113, 144, 114, 154))), axis=2)
        self.assertEqual(int(silhouette.sum()), 80)
        self.assertLess(np.mean(silhouette == silhouette[::-1]), .9)
        self.assertEqual(np.mean(silhouette[1:] == silhouette[:0:-1]), 1)
        popup = self.parse(image)
        self.assertEqual(popup['marker_boxes'], self.BOXES)
        self.assertEqual(popup['bounds'], (96, 119, 230, 369))
        self.assertEqual(popup['marker_x'], 108)
        self.assertEqual(popup['rows'], [133, 148.5, 164.5, 180.5, 196,
                         211.5, 227.5, 243, 258.5, 274.5, 290, 306,
                         321.5, 337.5, 353])

    def test_same_complete_popup_translated_uses_observed_component_bounds(self):
        image = self.image()
        control = Image.new('RGB', image.size, (0, 0, 0))
        control.paste(image.crop((90, 115, 235, 374)), (360, 84))
        popup = self.parse(control)
        self.assertEqual(popup['marker_boxes'],
                         [(l + 270, t - 31, r + 270, b - 31)
                          for l, t, r, b in self.BOXES])
        self.assertEqual(popup['marker_x'], 378)

    def test_missing_phase_shifted_selected_middle_or_all_circles_still_rejected(self):
        for name, boxes in [('phase_shifted', self.BOXES[1:2]),
                            ('selected', self.BOXES[9:10]),
                            ('middle', self.BOXES[7:8]), ('all', self.BOXES)]:
            with self.subTest(control=name):
                image = self.image()
                for box in boxes:
                    self.erase(image, box)
                with self.assertRaisesRegex(AssertionError, '0 complete popup/column'):
                    self.parse(image)

    def test_two_pixel_asymmetry_rejected_with_full_bounds_corners_and_cross(self):
        import numpy as np
        image = self.image()
        for y in range(146, 149):
            ImageDraw.Draw(image).line((111, y, 112, y),
                                      fill=image.getpixel((113, y)))
        silhouette = np.any(np.asarray(image.crop(self.BOXES[1])) !=
                            np.asarray(image.crop((113, 144, 114, 154))), axis=2)
        self.assertEqual(silhouette.shape, (10, 9))
        self.assertTrue(silhouette[5, :].all() and silhouette[:, 4].all())
        self.assertFalse(silhouette[0, 0] or silhouette[0, -1] or
                         silhouette[-1, 0] or silhouette[-1, -1])
        self.assertTrue(silhouette[0].any() and silhouette[-1].any() and
                        silhouette[:, 0].any() and silhouette[:, -1].any())
        with self.assertRaisesRegex(AssertionError, '0 complete popup/column'):
            self.parse(image)

    def test_T_duplicate_complete_panel_stays_ambiguous(self):
        image = self.image()
        image.paste(image.crop((94, 117, 232, 371)), (340, 117))
        with self.assertRaisesRegex(AssertionError, '2 complete popup/column'):
            self.parse(image)




class CurrentTitleTests(unittest.TestCase):
    def image(self):
        return Image.open(FIXTURES / 'title_37950_current.png').convert('RGB')

    def locate(self,image):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'title.png';image.save(path)
            return helper.locate_pixel_control(path,'开发入口',exact=True)

    def test_current_raw_fixture_and_real_unique_label(self):
        raw=(FIXTURES/'title_37950_current.png').read_bytes()
        provenance=json.loads((FIXTURES/'title_37950_current.json').read_text())
        self.assertEqual(hashlib.sha256(raw).hexdigest(),provenance['sha256'])
        point=self.locate(self.image())
        self.assertTrue(52<point[0]<412 and 482<point[1]<536)

    def test_current_title_is_shared_navigation_consumer(self):
        raw=(FIXTURES/'title_37950_current.png').read_bytes();observation={}
        with tempfile.TemporaryDirectory() as directory:
            point=helper._studio_title_from_pixels(raw,Path(directory),'current',observation,'')
        self.assertEqual(observation['actual_title_label'],'开发入口')
        self.assertEqual(point,self.locate(self.image()))

    def test_duplicate_current_labels_are_not_index_selected(self):
        image=self.image();image.paste(image.crop((50,480,414,540)),(50,570))
        with self.assertRaisesRegex(AssertionError,'found 2 complete button matches'):
            self.locate(image)

    def test_clipped_or_missing_current_label_does_not_click_surface(self):
        image=self.image();blank=image.copy()
        ImageDraw.Draw(blank).rectangle((64,495,170,523),fill=image.getpixel((200,510)))
        for control in (image.crop((0,0,1280,518)),blank):
            with self.subTest(size=control.size),self.assertRaises(ValueError):self.locate(control)

    def test_current_exact_rows_refuse_suffix_substring_and_duplicate(self):
        rows=ExactLabelTests().tsv
        self.assertEqual(helper._studio_label_box(rows(['开发入口']),'开发入口'),(65,36))
        for label in ('开发','开发入口2','更多开发入口','开发入口 OTHER'):
            with self.subTest(label=label),self.assertRaises(helper.StudioMenuLabelMissing):
                helper._studio_label_box(rows([label]),'开发入口')
        with self.assertRaisesRegex(AssertionError,'found 2'):
            helper._studio_label_box(rows(['开发入口','开发入口']),'开发入口')

class CurrentStudioControlsTests(unittest.TestCase):
    def locate(self,image,control,scale=1):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'frame.png';image.save(path)
            return helper._studio_bitmap_control(path,control,scale)

    def reference(self,image,control):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'frame.png';image.save(path)
            return helper._studio_current_reference(path,control)

    def test_real_desktop_full_font_glyphs_and_source_labels(self):
        image=Image.open(FIXTURES/'controls_37950_desktop.png')
        for control,label in [('weapon','Lv.1 脉冲枪'),('training','敌人：巡逻'),('practice','武器靶场'),('hook_practice','钩索接力')]:
            with self.subTest(control=control):
                result=self.locate(image,control)
                self.assertEqual(result['label'],label)
                l,t,r,b=result['bounds'];x,y=result['point']
                self.assertTrue(l<x<r and t<y<b)

    def test_real_touch_weapon_and_training_exact_scaled_font(self):
        image=Image.open(FIXTURES/'controls_37950_touch.png')
        self.assertEqual(self.locate(image,'weapon',390/720)['point'],(139,155.5))
        self.assertEqual(self.locate(image,'training',390/720)['point'],(556,155.5))
        self.assertEqual(self.locate(image,'practice',390/720)['point'],(269.5,155.5))
        self.assertEqual(self.locate(image,'hook_practice',390/720)['point'],(404.5,82.0))

    def test_control_suffix_wrong_glyph_duplicate_and_clipping_rejected(self):
        original=Image.open(FIXTURES/'controls_37950_desktop.png').convert('RGB')
        changed=original.copy();ImageDraw.Draw(changed).point((840,287),fill=(41,58,59) if original.getpixel((840,287))==(246,232,191) else (246,232,191))
        suffix=original.copy();ImageDraw.Draw(suffix).rectangle((950,280,952,287),fill=(246,232,191))
        duplicate=original.copy();duplicate.paste(original.crop((810,252,966,320)),(650,360))
        clipped=original.crop((0,0,940,720))
        for image in [changed,suffix,duplicate,clipped]:
            with self.subTest(size=image.size),self.assertRaises(AssertionError):self.locate(image,'training')

    def test_two_observed_title_viewports_strict_raw_glyphs(self):
        for name in ['title_37950_current.png','navigation_touch_title_37950.png']:
            image=Image.open(FIXTURES/name)
            self.assertEqual(len(self.reference(image,'title')),2)
        image=Image.open(FIXTURES/'navigation_touch_title_37950.png').convert('RGB')
        duplicate=image.copy();duplicate.paste(image.crop((103,260,301,294)),(400,260))
        changed=image.copy();ImageDraw.Draw(changed).rectangle((153,274,155,278),fill=(246,232,191))
        for frame in [duplicate,changed,image.crop((0,0,844,280)),image.resize((800,370))]:
            with self.subTest(size=frame.size),self.assertRaises(AssertionError):self.reference(frame,'title')

    def test_touch_actions_source_bound_edges_all_pixels_required(self):
        image=Image.open(FIXTURES/'navigation_touch_actions_37950.png').convert('RGB')
        self.assertEqual(self.reference(image,'actions'),(292,160))
        variants=[]
        for y in (143,175):
            changed=image.copy();ImageDraw.Draw(changed).line((223,y,361,y),fill=(37,53,56));variants.append(changed)
        duplicate=image.copy();duplicate.paste(image.crop((223,143,362,176)),(400,210));variants.append(duplicate)
        suffix=image.copy();ImageDraw.Draw(suffix).rectangle((354,154,356,160),fill=(246,232,191));variants.append(suffix)
        variants.append(image.crop((0,0,844,170)))
        for frame in variants:
            with self.subTest(size=frame.size),self.assertRaises(AssertionError):self.reference(frame,'actions')

    def test_source_font_resource_and_reference_drift_rejected(self):
        import shutil
        source=Path(helper.__file__).resolve().parents[1]
        meta=json.loads((FIXTURES/'current_navigation_37950.json').read_text())
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for name in meta['source_sha256']:
                target=root/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source/name,target)
            target=root/'tests/fixtures/studio_gui_pointer';shutil.copytree(FIXTURES,target)
            frame=target/'navigation_touch_title_37950.png'
            for name in ['assets/ui/demo_ui_01/r2/fonts/fusion-pixel-12px-proportional-zh_hans.otf','resources/weapons/pulse_gun.tres','game/presentation/ui/demo_ui_01/game_typography.gd']:
                path=root/name;original=path.read_bytes();path.write_bytes(original+b'\n')
                with self.subTest(source=name),self.assertRaisesRegex(AssertionError,'source drift'):
                    helper._studio_current_reference(frame,'title',root)
                path.write_bytes(original)
            frame.write_bytes(frame.read_bytes()+b'\n')
            with self.assertRaisesRegex(AssertionError,'raw reference drift'):helper._studio_current_reference(frame,'title',root)

    def test_touch_practice_raw_glyph_duplicates_suffix_and_clipping_rejected(self):
        original=Image.open(FIXTURES/'controls_37950_touch.png').convert('RGB')
        for control,crop,point in [('hook_practice',(370,63,442,100),(405,82)),('practice',(233,136,306,175),(270,155))]:
            duplicate=original.copy();duplicate.paste(original.crop(crop),(500,220))
            changed=original.copy();ImageDraw.Draw(changed).point(point,fill=(41,58,59) if original.getpixel(point)==(246,232,191) else (246,232,191))
            suffix=original.copy();ImageDraw.Draw(suffix).rectangle((crop[2]-9,point[1]-2,crop[2]-8,point[1]+2),fill=(246,232,191))
            clipped=original.copy();ImageDraw.Draw(clipped).rectangle((crop[0],crop[1],point[0],crop[3]),fill=(37,53,56))
            for name,image in [('duplicate',duplicate),('changed_glyph',changed),('suffix',suffix),('clipped',clipped)]:
                with self.subTest(control=control,case=name),self.assertRaises(AssertionError):self.locate(image,control,390/720)
        with self.assertRaisesRegex(ValueError,'Unknown Studio control'):self.locate(original,'unknown',390/720)

    def test_mixed_font_and_raw_complete_controls_are_ambiguous(self):
        # Independent adversarial derivative: real current control plus a full
        # second control using another admitted raster of the same source font.
        # This is a negative fixture, never a claimed gameplay screenshot.
        image=Image.open(FIXTURES/'controls_37950_touch_mixed_derived.png')
        with self.assertRaisesRegex(AssertionError,'found 2 exact glyph matches'):
            self.locate(image,'hook_practice',390/720)

    def test_original_marker_algorithm_on_real_current_desktop_popup(self):
        image=Image.open(FIXTURES/'popup_37950_desktop.png')
        result=helper._weapon_popup_from_pixels(image,1,303)
        self.assertEqual(result['rows'],[181.5+36*i for i in range(15)])
        self.assertEqual(len(result['marker_boxes']),15)

class HookReferencePointTests(unittest.TestCase):
    # Authored reset-reference test fixture, not runtime configuration or a
    # claimed live camera projection. Gameplay assertions remain in the caller.
    def test_authored_points_unknown_case_and_unobserved_viewport(self):
        from types import SimpleNamespace
        page=SimpleNamespace(viewport_size={'width':1280,'height':720})
        self.assertEqual(helper.studio_hook_reference_point(page,'oblique'),(496.0,387.2))
        self.assertEqual(helper.studio_hook_reference_point(page,'vertical'),(432.0,347.2))
        for case in ('diagonal','',None):
            with self.subTest(case=case),self.assertRaises(ValueError):
                helper.studio_hook_reference_point(page,case)
        for size in ({'width':844,'height':390},{'width':1280,'height':721}):
            with self.subTest(size=size),self.assertRaisesRegex(AssertionError,'viewport'):
                helper.studio_hook_reference_point(SimpleNamespace(viewport_size=size),'oblique')

    def test_authored_point_rejects_actual_camera_anchor_and_origin_source_drift(self):
        import shutil
        from types import SimpleNamespace
        source=Path(helper.__file__).resolve().parents[1]
        metadata='tests/fixtures/studio_gui_pointer/current_navigation_37950.json'
        meta=json.loads((source/metadata).read_text())
        traversal='game/player/actions/traversal_ability.gd'
        page=SimpleNamespace(viewport_size={'width':1280,'height':720})
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for name in [metadata,*meta['source_sha256'],traversal]:
                target=root/name;target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(source/name,target)
            self.assertEqual(helper.studio_hook_reference_point(page,'oblique',root),(496.0,387.2))
            for name in ('experiments/motion/action_studio.gd',traversal):
                target=root/name;original=target.read_bytes();target.write_bytes(original+b'\n')
                with self.subTest(source=name),self.assertRaisesRegex(AssertionError,'source drift'):
                    helper.studio_hook_reference_point(page,'oblique',root)
                target.write_bytes(original)
            self.assertEqual(helper.studio_hook_reference_point(page,'vertical',root),(432.0,347.2))

if __name__ == '__main__':
    unittest.main(verbosity=2)
