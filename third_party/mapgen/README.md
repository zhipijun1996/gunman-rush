# Pinned map-gen delivery

`0.1.0/` is the unchanged extraction of the user-specified release:
https://raw.githubusercontent.com/zhipijun1996/map-gen/23047fa0d32c1e7e7c5bb7b2d93b76a5a9d4b12f/delivery/releases/0.1.0/mapgen-delivery-0.1.0.zip

ZIP SHA-256: `1c190a0a3918ece39e3a3aac7d35dbc855b9f4c87ebafbaa11f32c820a333b25`.
Run `python3 third_party/mapgen/0.1.0/verify_delivery.py` from the game repository.

The parent `.gdignore` keeps editor imports out of the immutable package. Native behavior is loaded explicitly; the host's independent adapters live in `scripts/mapgen/`. `addons/mapgen_delivery_export` exports the exact original bytes so runtime SHA checks also work in PCKs. No original module or manifest hash is patched.
