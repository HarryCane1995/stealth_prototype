extends MeshInstance3D

@export var line_color: Color = Color(1.0, 0.85, 0.1, 1.0)
@export var line_height: float = 0.1
@export var arc_segments: int = 12

var vision_range: float = 6.0
var vision_angle_degrees: float = 70.0


func update_vision(range_value: float, angle_degrees: float) -> void:
	vision_range = range_value
	vision_angle_degrees = angle_degrees
	_rebuild_mesh()


func _ready() -> void:
	_rebuild_mesh()


func _rebuild_mesh() -> void:
	var debug_mesh: ImmediateMesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = line_color

	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)

	var origin: Vector3 = Vector3(0.0, line_height, 0.0)
	var half_angle: float = deg_to_rad(vision_angle_degrees * 0.5)
	var left_edge: Vector3 = _direction_from_angle(-half_angle) * vision_range
	var right_edge: Vector3 = _direction_from_angle(half_angle) * vision_range
	var forward: Vector3 = Vector3(0.0, 0.0, -vision_range)

	_add_line(debug_mesh, origin, origin + forward)
	_add_line(debug_mesh, origin, origin + left_edge)
	_add_line(debug_mesh, origin, origin + right_edge)

	var previous_point: Vector3 = origin + left_edge
	for index in range(1, arc_segments + 1):
		var t: float = float(index) / float(arc_segments)
		var angle: float = -half_angle + (half_angle * 2.0 * t)
		var next_point: Vector3 = origin + _direction_from_angle(angle) * vision_range
		_add_line(debug_mesh, previous_point, next_point)
		previous_point = next_point

	debug_mesh.surface_end()
	mesh = debug_mesh


func _direction_from_angle(angle: float) -> Vector3:
	return Vector3(sin(angle), 0.0, -cos(angle))


func _add_line(debug_mesh: ImmediateMesh, from: Vector3, to: Vector3) -> void:
	debug_mesh.surface_add_vertex(from)
	debug_mesh.surface_add_vertex(to)
