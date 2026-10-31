class_name LevelContentValidation
extends RefCounted
## Primitive shapes shared by the concrete plan consumers, without coercion.
static func identity(value: Variant) -> bool:
	return (value is String or value is StringName) and not str(value).is_empty()

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func point(value: Variant) -> bool:
	return value is Array and value.size()==2 and number(value[0]) and number(value[1]) and Vector2(value[0],value[1]).is_finite()

static func rectangle(value: Variant) -> bool:
	return value is Array and value.size()==4 and number(value[0]) and number(value[1]) and number(value[2]) and number(value[3]) and float(value[2])>0 and float(value[3])>0 and Rect2(value[0],value[1],value[2],value[3]).position.is_finite() and Rect2(value[0],value[1],value[2],value[3]).size.is_finite()

static func rect(row: Array) -> Rect2:
	return Rect2(row[0],row[1],row[2],row[3])
