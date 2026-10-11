# Projectile art source

`projectiles.png` is an original transparent painterly atlas generated with OpenAI image generation on 2026-10-11 for this repository. It is not a third-party CC0 asset; the audio licenses do not apply to it. Original output retained in the session as `generated_images/exec-a4a4204c-054e-45e9-8c17-b8d46ea5f419.png`.

1280×1280, four 640×640 cells: thorn seed, wind crescent, gold spark and earth wind wave. `ProjectileArt` anchors the bright projectile head and scales decorative trails independently of gameplay collision. Actual consumers are `EnemyAttackProjectile` (thorn), `BossProjectile` (gold spark / Windkeeper ground wave). The wind crescent is delivered art for future projectile consumers, not a new implemented attack. Windmill blade and pier contact damage proxies remain invisible because their real warning/attack art already belongs to the encounter.

Prompt: transparent production game VFX atlas; four isolated right-facing hand-painted fantasy projectiles; crimson amber woody thorn seed, sage ivory leaf wind crescent, golden fire spark, earthy sage dust wave; rich ink silhouettes and clear bright heads; no text, UI or scenery.
