extends Node3D

@export var marker_color: Color = Color(1, 0.8, 0.2)
@export var label: String = "POI"
@export var target: Node3D

var float_offset: float = 0.0

func _ready():
	_create_marker()

func _process(delta):
	float_offset += delta * 1.5
	if target:
		global_position = target.global_position + Vector3(0, 8 + sin(float_offset) * 0.5, 0)

func _create_marker():
	var pillar = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = 0.3
	pillar.mesh = cyl
	pillar.position.y = 0.15
	var pm = StandardMaterial3D.new()
	pm.albedo_color = marker_color
	pm.emission_enabled = true
	pm.emission = marker_color
	pm.emission_energy_multiplier = 2.0
	pillar.material_override = pm
	add_child(pillar)

	var beacon = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	beacon.mesh = sphere
	beacon.position.y = 0.5
	var bm = StandardMaterial3D.new()
	bm.albedo_color = marker_color
	bm.emission_enabled = true
	bm.emission = marker_color
	bm.emission_energy_multiplier = 3.0
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color.a = 0.7
	beacon.material_override = bm
	add_child(beacon)
