# Restore reader audit after attempt03

Attempt03's native69/0 and immutable archive remain historical evidence. The original Python reader accepted three independent corruptions: activation clock zero, bound body/HP replacement, and a combat trace reduced to its final frame. That reader did not protect the full stated persistence scope.

The current reader now compares every persisted observed field at both bound and activated restore, fresh attack epochs, continuous full route/combat streams, route Motor/resource/damage observations, observed H state sequence and contact position, actual Body/phase events, and both ordered Policy/HealthState damage ledgers. Offline revalidation accepted the unchanged original03 and rejected all seven original independent corruptions plus 34 additional variants. These are offline results, not a new native run.

Original combat frames omit per-frame input requests, Motor-step count and Boss HP. The route event callback retains tick254 during subsequent combat. Consequently the reader checks ordered action/contact evidence and cross-ledger identities, but cannot prove frame-exact combat input/Policy causality. No additional timestamps were invented. This evidence does not admit the complete Boss or region.

Reproduction (repository root): `PYTHONDONTWRITEBYTECODE=1 python3 build/forest_depth/restore/reader-hardening01/offline_regression.py`. Original archives and native receipts were not rewritten. Independent re-review accepted this limited offline guard scope: `build/forest_depth/independent/restore-v6/recheck01/REVIEW.md`. Its independently implemented controls accepted the unchanged original03 and rejected46 variants. This does not add a native execution or fill the missing per-frame combat inputs.
