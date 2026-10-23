# v8 r2 real development failures

The first candidate5ffd and its full failures/review remain ../v8-first-review. This revision preserves its own exploratory logs; these precommit runs did not capture an exact source guard and cannot be rebound as final-source pass evidence.

- native-first458/8 followed new visible extent/anchor calibration; horizontal alpha-center adjustment initially moved the corpse node x, and the old flyer drawing foot extended below collision support. Horizontal correction now lives only in draw bounds, retaining exact lethal node x; real Motor-center-to-drawn-foot floor contact is verified for a straddled surface.
- native-second458/1: fresh saved legacy flyer had a drawn foot below floor; restore verifies actual saved collision foot±2wu instead of atlas alpha position. No distant-floor snap. Root subsequent458/0 preserved.
- GPU256/1: one actual aerial death remained onD3 after a frame foot change crossed a thin floor and the ray started below its top. Source report/log preserved. Sweeping from both previous and current alpha feet fixes the actual runtime miss; subsequent258/0 with the same original assertions. No test threshold was relaxed.
- Current formal count/remaining failure is taken from the independent final exact-runtime report; first candidate66/2 is not silently reused.
