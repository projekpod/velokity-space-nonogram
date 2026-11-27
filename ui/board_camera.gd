extends RefCounted

const MIN_CELL_PIXELS := 44.0
const CELL_GAP := 2.0

var edge := 0.0
var pan := Vector2.ZERO


func minimum_edge(frame: Rect2, cells: int, pixels_per_unit: float) -> float:
	return maxf(frame.size.x / cells, MIN_CELL_PIXELS / maxf(pixels_per_unit, 0.01) + CELL_GAP)


func fit() -> void:
	edge = 0.0
	pan = Vector2.ZERO


func cell_edge(frame: Rect2, cells: int) -> float:
	return edge if edge > 0.0 else frame.size.x / cells


func grid(frame: Rect2, cells: int) -> Rect2:
	return Rect2(frame.position + pan, Vector2.ONE * cell_edge(frame, cells) * cells)


func move(frame: Rect2, cells: int, offset: Vector2) -> void:
	pan = (pan + offset).clamp(frame.size - grid(frame, cells).size, Vector2.ZERO)


func zoom(frame: Rect2, cells: int, pixels_per_unit: float, requested: float, source: Vector2, destination: Vector2) -> void:
	var fitted := frame.size.x / cells
	if requested <= fitted + 0.001:
		fit()
		return
	var target := (source - grid(frame, cells).position) / cell_edge(frame, cells)
	var minimum := minimum_edge(frame, cells, pixels_per_unit)
	edge = clampf(requested, minimum, maxf(fitted * 3.0, minimum * 1.5))
	pan = destination - frame.position - target * edge
	move(frame, cells, Vector2.ZERO)


func cell_at(frame: Rect2, cells: int, point: Vector2) -> Vector2i:
	if not frame.has_point(point):
		return Vector2i(-1, -1)
	return Vector2i(((point - grid(frame, cells).position) / cell_edge(frame, cells)).floor()).clamp(Vector2i.ZERO, Vector2i.ONE * (cells - 1))
