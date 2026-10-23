# V6 packaging timing correction

The first actual packaging attempt failed the existing strict 60/1 frame-rate guard. Its 14-second movie contained 840 frames, but concat timestamps produced avg_frame_rate=40000000/665873. The failed receipt is retained in packaging-first-rejected-recipe.json; the original rejected directory and actual probe are recorded in recipe.json.

This retry sets the concatenated video time base to 1/60 and assigns each original frame PTS=N. Encoder time base is 1:60 with passthrough frame scheduling. No fps/interpolation filter, frame duplication or speed change is applied. The strict 60/1 guard remains and output frame counts must be exactly 840 and 1200. Audio is trimmed from the same intervals at its original speed.

These are packaging observations only; no independent review, user approval or device claim is made.

The first timing-fix attempt also failed before encoding: this FFmpeg rejects the combination of output -r 60 and passthrough scheduling (exit 234). Its complete command/stderr/receipt is retained in packaging-second-rejected-recipe.json. This retry removes -r, retaining explicit filter/encoder 1/60 time bases, PTS=N, passthrough scheduling and the unchanged 60/1 plus exact-frame-count guards.

The time-base-only passthrough retry produced 840 frames but a zero-duration last video packet: video duration 13.983333s, avg_frame_rate=50400/839. The unchanged strict guard rejected it; its complete receipt is retained in packaging-third-rejected-recipe.json. The final retry retains exact 1/60 PTS=N and uses output -r 60 / -fps_mode cfr so the final packet receives its normal 1/60-second duration. No interpolation filter is applied; output must still contain exactly 840/1200 selected original frames at 60/1.
