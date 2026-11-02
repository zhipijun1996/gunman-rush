extends RefCounted
## Export-safe task metadata, generated from the unchanged-source measurement JSON.
## JSON remains the auditable processing record; no shared export preset changes.
const DATA: Dictionary = {
	"version": "motion-candidate-v1",
	"texture": "res://assets/player_presentation_01/motion_v1/motion_source.png",
	"source_sha256": "d0a7d99429de680a0e3c19a55398bca836a43165e96f33712f00d4e5cf1d3280",
	"reference_body_height": 182.0,
	"scale_policy": "one uniform page scale;44wu via UnderworldActors.HUMANOID_HEIGHT;nearest;no pixel edits",
	"frames": {
		"idle": [
			{
				"rect": [
					0,
					0,
					256,
					256
				],
				"pivot": [
					168,
					242
				],
				"opaque_bounds": [
					43,
					60,
					251,
					242
				],
				"index": 0
			},
			{
				"rect": [
					256,
					0,
					256,
					256
				],
				"pivot": [
					173,
					242
				],
				"opaque_bounds": [
					62,
					60,
					256,
					242
				],
				"index": 1
			},
			{
				"rect": [
					512,
					0,
					256,
					256
				],
				"pivot": [
					144,
					242
				],
				"opaque_bounds": [
					43,
					60,
					227,
					242
				],
				"index": 2
			},
			{
				"rect": [
					768,
					0,
					256,
					256
				],
				"pivot": [
					129,
					242
				],
				"opaque_bounds": [
					23,
					60,
					212,
					242
				],
				"index": 3
			},
			{
				"rect": [
					1024,
					0,
					256,
					256
				],
				"pivot": [
					119,
					242
				],
				"opaque_bounds": [
					19,
					60,
					202,
					242
				],
				"index": 4
			},
			{
				"rect": [
					1280,
					0,
					256,
					256
				],
				"pivot": [
					125,
					242
				],
				"opaque_bounds": [
					14,
					60,
					208,
					242
				],
				"index": 5
			}
		],
		"fall": [
			{
				"rect": [
					0,
					256,
					256,
					256
				],
				"pivot": [
					162,
					233
				],
				"opaque_bounds": [
					49,
					51,
					245,
					233
				],
				"index": 0
			},
			{
				"rect": [
					256,
					256,
					256,
					256
				],
				"pivot": [
					173,
					233
				],
				"opaque_bounds": [
					62,
					47,
					256,
					233
				],
				"index": 1
			},
			{
				"rect": [
					512,
					256,
					256,
					256
				],
				"pivot": [
					170,
					233
				],
				"opaque_bounds": [
					56,
					47,
					253,
					229
				],
				"index": 2
			},
			{
				"rect": [
					768,
					256,
					256,
					256
				],
				"pivot": [
					159,
					233
				],
				"opaque_bounds": [
					49,
					51,
					242,
					233
				],
				"index": 3
			},
			{
				"rect": [
					1024,
					256,
					256,
					256
				],
				"pivot": [
					137,
					233
				],
				"opaque_bounds": [
					41,
					43,
					220,
					233
				],
				"index": 4
			},
			{
				"rect": [
					1280,
					256,
					256,
					256
				],
				"pivot": [
					125,
					233
				],
				"opaque_bounds": [
					17,
					46,
					208,
					229
				],
				"index": 5
			}
		]
	},
	"sampling": [
		{
			"state": "idle",
			"cuts": [
				0,
				256,
				512,
				768,
				1024,
				1280,
				1536
			],
			"baseline": 242
		},
		{
			"state": "fall",
			"cuts": [
				0,
				256,
				512,
				768,
				1024,
				1280,
				1536
			],
			"baseline": 233
		}
	],
	"unused_rows": [
		2,
		3
	],
	"unused_reason": "two independent run source attempts rejected;retain old run atlas;not all24frames consumed",
	"operations": [
		"original imagegen PNG copied byte-for-byte",
		"read-only alpha>=128 bounding measurement",
		"explicit nonoverlap source rectangles and declared pivots only;no alpha thresholding of rendered art"
	],
	"source_grid": "measured frame regions, not an accepted regular-grid claim",
	"pivot_note": "Head-strip measured reference minus83srcpx. This puts the 44wu silhouette into the retained formal body envelope; no root/Motor/collider/weapon-anchor change."
}
