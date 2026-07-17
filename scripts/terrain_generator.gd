@tool
extends MeshInstance3D

@export var width: int = 200
@export var depth: int = 200
@export var height_scale: float = 30.0
@export var mountain_height: float = 60.0
@export var mountain_radius: float = 40.0
@export var noise_scale: float = 0.05

func _ready():
	_generate()

func _generate():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w = width / 2.0
	var half_d = depth / 2.0
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_scale
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5

	for z in range(depth):
		for x in range(width):
			var wx = x - half_w
			var wz = z - half_d
			var dist = Vector2(wx, wz).length()
			var h = noise.get_noise_2d(x, z) * height_scale
			var mountain = max(0, 1.0 - dist / mountain_radius)
			h += mountain * mountain * mountain_height
			h = max(h, -2.0)
			var uv = Vector2(x / float(width), z / float(depth))
			st.set_uv(uv)
			st.set_uv2(uv)
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(wx, h, wz))

	for z in range(depth - 1):
		for x in range(width - 1):
			var i = z * width + x
			var v1 = i
			var v2 = i + 1
			var v3 = (z + 1) * width + x
			var v4 = v3 + 1
			st.add_index(v1)
			st.add_index(v2)
			st.add_index(v3)
			st.add_index(v2)
			st.add_index(v4)
			st.add_index(v3)

	st.generate_normals()
	st.generate_tangents()
	mesh = st.commit()
	if mesh:
		var shape = ConcavePolygonShape3D.new()
		shape.set_faces(mesh.get_faces())
		var col = CollisionShape3D.new()
		col.shape = shape
		add_child(col)
		col.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner

func _get_configuration_warnings():
	if not MeshInstance3D.new() is MeshInstance3D:
		return ["Requires MeshInstance3D"]
	return []
