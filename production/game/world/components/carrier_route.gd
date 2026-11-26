class_name CarrierRoute
extends RefCounted
## Relative path. Manual carts use arc length, shuttles and seeds ease through each span.
var points: Array[Vector2] = []
var length := 0.0

func configure(endpoint: Vector2, route: Array[Vector2]) -> void:
	points.assign(route if not route.is_empty() else [endpoint])
	length = 0.0
	var previous := Vector2.ZERO
	for point in points:
		length += previous.distance_to(point)
		previous = point

func cycle(clock: float,period: float,endpoint_dwell: float) -> Vector2:
	var elapsed := fposmod(clock,period + 2*endpoint_dwell)
	var half := period * .5
	var progress := clampf((elapsed-endpoint_dwell)/half,0,1)
	if elapsed > endpoint_dwell*2+half:
		progress = clampf(1.0-(elapsed-endpoint_dwell*2-half)/half,0,1)
	return sample(progress*length,true)

func sample(distance: float, smooth: bool) -> Vector2:
	var previous := Vector2.ZERO
	for point in points:
		var segment_length := previous.distance_to(point)
		if distance <= segment_length and segment_length > 0:
			var fraction := clampf(distance/segment_length,0.0,1.0)
			if smooth: fraction = .5-.5*cos(PI*fraction)
			return previous.lerp(point,fraction)
		distance -= segment_length
		previous = point
	return previous
