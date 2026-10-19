"""Rebuild OFL Chinese UI subset from the original Noto Sans SC variable font."""
import argparse
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path, help='original Google Fonts NotoSansSC variable TTF')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
paths = ['scripts/bosses/windkeeper_encounter.gd', 'scripts/bosses/windkeeper_presentation.gd',
         'scripts/ui/windkeeper_hud.gd', 'scripts/ui/actor_resources_hud.gd', 'scripts/ui/demo_menu.gd',
         'scripts/demo/demo_app.gd', 'scripts/bosses/bellstrider_encounter.gd',
         'resources/bosses/bellstrider.tres']
characters = set(range(32, 127))
# Preserve the existing dynamic navigation arrow alongside current UI literals.
characters.add(0x2192)
paths += [str(p.relative_to(root)) for p in (root / "resources/items").glob("*.tres")]
# Boss HUD consumes each encounter's actual objective/display_name. Include new
# encounters here, rather than manually adding a font exception for each region.
paths += [str(p.relative_to(root)) for directory, pattern in
          [("scripts/bosses", "*.gd"), ("resources/bosses", "*.tres")]
          for p in (root / directory).glob(pattern)]
paths += ["scripts/rewards/resource_reward_choice.gd", "scripts/ui/item_card.gd", "scripts/ui/item_presentation.gd", "scripts/ui/item_acquired_toast.gd"]
previous = root / 'assets/fonts/windkeeper_ui.ttf'
if previous.is_file():
    with TTFont(previous) as existing:
        characters.update(existing.getBestCmap())
for path in paths:
    characters.update(ord(character) for character in (root / path).read_text() if ord(character) >= 128)
font = TTFont(args.source)
instantiateVariableFont(font, {'wght': 600}, inplace=True)
options = subset.Options()
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=characters)
subsetter.subset(font)
font.save(root / 'assets/fonts/windkeeper_ui.ttf')
print(f'Subset: {len(characters)} UI characters, ASCII and all current Chinese hints')
