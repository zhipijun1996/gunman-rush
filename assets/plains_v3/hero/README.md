# Plains v3 courier

Original AI-generated RGBA PNGs, copied unchanged. `manifest.json` gives source regions, feet pivots and shoulder anchors. Six states contain 16 distinct frames: idle4 / run4 / jump2 / fall1 / recoil2 / death3. Apply one uniform scale (104/320) to all body frames; do not resize each pose to the same bounding height. The action sheet row boundary is y=480, rather than the arithmetic half, because first-row boots extend below y=444. Read the actual regions.

Body sprites contain no gun. The independent brass pistol is a separate texture and is drawn with its own aim angle; keep physics, combat muzzle and collision consumer-owned. `barrel_angle_degrees=0` permits existing 360-degree aim. Small painted hand remains beside torso rather than tracking the separate pistol; this is a visual limitation, not a restriction on aim.

Use normal RGBA alpha blending. Transparent pixels can retain colored RGB haze; those pixels do not create a visible aura in correct alpha rendering. No pixel editing, cropping, palette conversion or source resampling was used. AtlasTexture/Canvas regions are rendering instructions only.

The lower-right fallen pose is an optional third death settle frame. Feet, shoulder and muzzle pivots are manually estimated art anchors; final tiny-scale and all-direction visual review remain required. The pack does not change animation state policy, Motor, collision or recoil parameters.
