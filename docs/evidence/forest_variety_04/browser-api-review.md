# Direct API guard follow-up

Read-only confirmation of root's two-line entry guard in tools/verify_forest_browser.py. New SHA256: 3d75e424e528dd41da56d58b077fb2e3be598206bd415349b92ce9942d09a1a3.

Isolated pure-Python direct verify() calls now reject candidate mode with missing expectations, v15 layout, missing region version, or v1 region version before even attempting folder.mkdir. Exact v2/v18 reaches a sentinel folder.mkdir and stops there. No folder writes, browser launch or engine. Reproduction and results: /tmp/forest-v18-browser-api-review.py and .json. This closes the prior CLI-only coupling note. Source diff outside the added guard remains the earlier reviewed candidate-option implementation; actual GUI execution remains unverified by this review.
