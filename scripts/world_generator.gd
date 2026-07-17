@tool
extends Node3D

var noise: FastNoiseLite

func _ready():
	if Engine.is_editor_hint():
		return
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.008
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.5
	_generate()

func _generate():
	_ground()
	_portals()
	_buildings()
	_environment()

func h(x: float, z: float) -> float:
	var raw = noise.get_noise_2d(x, z)
	var dist = Vector2(x, z).length()
	var mountain = max(0, 1.0 - dist / 90.0)
	var peak = mountain * mountain * 55.0
	var ridge = max(0, 1.0 - abs(dist - 50) / 25.0) * 15.0 * max(0, sin(x * 0.3 + z * 0.2))
	return raw * 8.0 + peak + ridge

func _ground():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var res = 120
	var size = 300.0
	var half = size / 2.0
	var step = size / res
	
	for z in range(res + 1):
		for x in range(res + 1):
			var wx = x * step - half
			var wz = z * step - half
			var y = h(wx, wz)
			st.set_normal(Vector3(0, 1, 0))
			st.set_uv(Vector2(x / float(res), z / float(res)))
			st.add_vertex(Vector3(wx, y, wz))
	
	for z in range(res):
		for x in range(res):
			var i = z * (res + 1) + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + res + 1)
			st.add_index(i + 1)
			st.add_index(i + res + 2)
			st.add_index(i + res + 1)
	
	st.generate_normals()
	var mesh = st.commit()
	
	var mi = MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.33, 0.28)
	mat.roughness = 0.95
	mi.material_override = mat
	add_child(mi)
	mi.owner = self
	
	var body = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	shape.owner = body
	mi.add_child(body)
	body.owner = self

func _concrete():
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.53, 0.5)
	m.roughness = 0.8
	return m

func _red():
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.18, 0.12)
	m.roughness = 0.7
	return m

func _dark():
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.15, 0.12, 0.1)
	m.roughness = 0.9
	return m

func _make_portal(name: String, pos: Vector3, rot: float, title: String, info: String):
	var root = Node3D.new()
	root.name = name
	root.position = pos
	root.rotation.y = rot
	add_child(root)
	root.owner = self
	
	var tunnel = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 3.5
	cyl.bottom_radius = 4.0
	cyl.height = 8.0
	tunnel.mesh = cyl
	tunnel.position = Vector3(0, 2.5, -4)
	tunnel.material_override = _concrete()
	root.add_child(tunnel)
	tunnel.owner = self
	
	var frame = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(7, 5, 1.5)
	frame.mesh = box
	frame.position = Vector3(0, 3, 1)
	frame.material_override = _concrete()
	root.add_child(frame)
	frame.owner = self
	
	var arch = MeshInstance3D.new()
	var abox = BoxMesh.new()
	abox.size = Vector3(1, 3, 1)
	arch.mesh = abox
	arch.position = Vector3(-3.5, 3.5, 0)
	arch.material_override = _concrete()
	root.add_child(arch)
	arch.owner = self
	
	var arch2 = arch.duplicate()
	arch2.position.x = 3.5
	root.add_child(arch2)
	arch2.owner = self
	
	var tunnel_inside = MeshInstance3D.new()
	var tcyl = CylinderMesh.new()
	tcyl.top_radius = 2.5
	tcyl.bottom_radius = 2.5
	tcyl.height = 10.0
	tunnel_inside.mesh = tcyl
	tunnel_inside.position = Vector3(0, 1.5, -5)
	tunnel_inside.material_override = _dark()
	root.add_child(tunnel_inside)
	tunnel_inside.owner = self
	
	var sign = MeshInstance3D.new()
	var sbox = BoxMesh.new()
	sbox.size = Vector3(3, 1, 0.1)
	sign.mesh = sbox
	sign.position = Vector3(0, 6.5, 2.5)
	sign.material_override = _red()
	root.add_child(sign)
	sign.owner = self
	
	var area = Area3D.new()
	area.name = "Interactable"
	area.position = Vector3(0, 5, 3)
	root.add_child(area)
	area.owner = self
	var script = load("res://scripts/interactable.gd")
	area.set_script(script)
	area.title = title
	area.info = info
	var col = CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(5, 4, 4)
	area.add_child(col)
	col.owner = self

func _portals():
	_make_portal("Portal1_South", Vector3(35, 5, 55), 0.2,
		"1번 갱도 - South Portal",
		"2006년 10월 9일 - 1차 핵실험\n동쪽 갱도, 입구에서 1km 내부\n埋深 약 310m | 추정 폭발력 < 1kt\n상태: 폐쇄 및 붕괴")
	_make_portal("Portal2_East", Vector3(80, 7, 25), -0.4,
		"2번 갱도 - East Portal",
		"4차(2016.1.6), 5차(2016.9.9), 6차(2017.9.3) 핵실험\n6차: 규모 6.3, 50-250kt (역대 최대)\n2018.5.24 폭파 폐기\n2021년 이후 복구 활동 감지")
	_make_portal("Portal3_West", Vector3(-65, 4, 20), 0.7,
		"3번 갱도 - West Portal",
		"2차(2009.5.25), 3차(2013.2.12) 핵실험\n2차: 4-6kt | 3차: 6-7kt\n埋深 약 490m\n2018.5.24 폭파 폐기")
	_make_portal("Portal4_North", Vector3(20, 2, -55), 3.0,
		"4번 갱도 - North Portal",
		"신규 갱도 - 핵실험에 사용된 적 없음\n2022년 이후 복구 활동 다수 관측\n7차 핵실험 가능성 지속 제기\n상태: 사용 준비 완료 추정")

func _make_building(name: String, pos: Vector3, size: Vector3, title: String, info: String):
	var root = Node3D.new()
	root.name = name
	root.position = pos
	add_child(root)
	root.owner = self
	
	var main = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	main.mesh = box
	main.position = Vector3(0, size.y / 2, 0)
	main.material_override = _concrete()
	root.add_child(main)
	main.owner = self
	
	var roof = MeshInstance3D.new()
	var rbox = BoxMesh.new()
	rbox.size = Vector3(size.x + 1, 0.4, size.z + 1)
	roof.mesh = rbox
	roof.position = Vector3(0, size.y + 0.2, 0)
	roof.material_override = _red()
	root.add_child(roof)
	roof.owner = self
	
	for i in range(2):
		var window = MeshInstance3D.new()
		var wbox = BoxMesh.new()
		wbox.size = Vector3(1.2, 1.2, 0.05)
		window.mesh = wbox
		window.position = Vector3(size.x / 2 + 0.03, size.y * 0.6, (i - 0.5) * size.z * 0.5)
		window.material_override = StandardMaterial3D.new()
		window.material_override.albedo_color = Color(0.6, 0.7, 0.85)
		window.material_override.emission_enabled = true
		window.material_override.emission = Color(0.6, 0.7, 0.85)
		window.material_override.emission_energy_multiplier = 0.5
		root.add_child(window)
		window.owner = self
	
	var area = Area3D.new()
	area.name = "Interactable"
	area.position = Vector3(0, 2, size.z / 2 + 2)
	root.add_child(area)
	area.owner = self
	var script = load("res://scripts/interactable.gd")
	area.set_script(script)
	area.title = title
	area.info = info
	var col = CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(size.x + 2, 3, 3)
	area.add_child(col)
	col.owner = self

func _buildings():
	_make_building("AdminBuilding", Vector3(-15, 8, 100), Vector3(14, 6, 10),
		"주행정동 (Main Administrative Area)",
		"핵실험장 주요 행정/지휘 시설\n2층 본부 건물 및 지원시설 (차량기지, 숙소, 창고)\n상주인원: 수백 명 규모\n차량 및 장비 활동 지속 관측")
	_make_building("GuardPost", Vector3(40, 4, 80), Vector3(6, 3, 5),
		"경비초소 (Guard Post)",
		"진입로 검문소 및 경비병력 숙소\n출입 통제 및 보안 담당")
	_make_building("ObservationPost", Vector3(25, 18, 60), Vector3(5, 3, 5),
		"관측소 (Observation Post)",
		"핵실험 관측 및 계측 시설\n만탑산 남측 능선에 위치\n지진파 및 방사능 모니터링")
	_make_building("SupportBuilding", Vector3(50, 7, 95), Vector3(10, 4, 8),
		"남측 지원구역 (Southern Support Area)",
		"장비 보관 및 정비 시설\n건설 자재 적치장\n차량 운행 기지")

func _environment():
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(-0.6, 0.7, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_bias = 0.02
	add_child(sun)
	sun.owner = self
	
	var ambient = DirectionalLight3D.new()
	ambient.name = "Ambient"
	ambient.light_energy = 0.15
	ambient.light_color = Color(0.6, 0.7, 0.9)
	add_child(ambient)
	ambient.owner = self
	
	var env = WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var e = Environment.new()
	e.background_color = Color(0.45, 0.6, 0.85)
	e.tonemap_mode = 2
	e.ambient_light_color = Color(0.3, 0.35, 0.45)
	e.ambient_light_energy = 0.3
	env.environment = e
	add_child(env)
	env.owner = self
	
	var fog = MeshInstance3D.new()
	fog.name = "FogHint"
	var fbox = BoxMesh.new()
	fbox.size = Vector3(400, 20, 400)
	fog.mesh = fbox
	fog.position = Vector3(0, 5, 0)
	var fmat = StandardMaterial3D.new()
	fmat.albedo_color = Color(0.6, 0.7, 0.85, 0.02)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog.material_override = fmat
	add_child(fog)
	fog.owner = self
