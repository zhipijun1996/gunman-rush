# Actual v8 development failures

These raw precommit logs/screenshots are retained in precommit-failures.tar.gz; exact source commit/guard was not captured for these exploratory runs. They must not become final-source pass evidence.

- Native initial446/0 preceded final tests. Later458/4 assumed the atlas origin was the visible foot; the assertion now uses actual origin+frame alpha-foot at the same380.01 threshold and preserves the original lethal-x precision.458/0 after correction.
- GPU244/2 first looked like bad foot contact. The preserved reports show floor_screen_y=INF: the observer ray started on/in the collider. This was a measurement failure, not proof of a real rendered foot gap.
- GPU250/4 also contained script errors after cleared source=null and a leaf-only visibility mask excluding ancestors. Observer fixes safely report zero samples for cleared source and temporarily expose only the leaf's ancestor path, restoring every layer/mask.
- GPU258/2 retained the same INF floor-ray mistake after those fixes. The corrected ray begins2wu above the actual alpha foot; the original absolute rendered gap<=3px threshold remains. Final258/0 has real surface measurements.
- Production per-frame alpha-foot placement was also added, with one cached foot per index. Tests never rotate art or relax thresholds to pass.
- Formal66/2 is a current production save/restore failure and remains failed, not an observer mistake; report/log and independent execution are separate.
