extends "res://tests/quality_review_runner.gd"
func run()->void:
	await region_art_consumer()
	print("INDEPENDENT REGION LIFECYCLE: %s assertions, %s failures"%[checks,failures])
	quit(1 if failures else 0)
