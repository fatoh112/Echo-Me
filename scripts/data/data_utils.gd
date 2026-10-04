extends RefCounted
class_name DataUtils


static func read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read data: " + path)
		return null
	return JSON.parse_string(file.get_as_text())


static func dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


static func number(value: Variant, fallback: float = 0.5) -> float:
	if not (value is float or value is int):
		return fallback
	var result := float(value)
	return fallback if is_nan(result) or is_inf(result) else result


static func unit(value: Variant, fallback: float = 0.5) -> float:
	return clampf(number(value, fallback), 0.0, 1.0)
