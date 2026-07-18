@tool
extends Node3D

var noise: FastNoiseLite
var tree_noise: FastNoiseLite
var detail_noise: FastNoiseLite

var _tree_packed: PackedScene
var _bush_packed: PackedScene
var _rock_packed: PackedScene
var _sign_packed: PackedScene
var _has_models := false

func _ready():
	if Engine.is_editor_hint():
		return
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.007
	noise.fractal_octaves = 6
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.3

	tree_noise = FastNoiseLite.new()
	tree_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	tree_noise.frequency = 0.015
	tree_noise.fractal_octaves = 2
	tree_noise.fractal_gain = 0.5

	detail_noise = FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	detail_noise.frequency = 0.03

	_load_models()
	_generate()

func _load_glb(path: String) -> PackedScene:
	if ResourceLoader.exists(path):
		return load(path) as PackedScene
	if not FileAccess.file_exists(path):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		return null
	var root := doc.generate_scene(state)
	if not root:
		return null
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	return ps

func _load_models():
	var candidates := [
		"res://models/glb/mini_forest/tree.glb",
		"res://models/glb/mini_forest/tree-high.glb",
		"res://models/glb/mini_forest/plant.glb",
		"res://models/glb/mini_forest/rocks-high.glb",
		"res://models/glb/mini_forest/stones.glb",
	]
	for p in candidates:
		var ps := _load_glb(p)
		if ps:
			if not _tree_packed:
				_tree_packed = ps
			_bush_packed = ps if p.contains("plant") else _bush_packed
			_rock_packed = ps if p.contains("rock") or p.contains("stone") else _rock_packed
	if _tree_packed:
		_has_models = true
		print("[WorldGenerator] GLB tree models loaded OK")

func h(x: float, z: float) -> float:
	var raw = noise.get_noise_2d(x, z)
	var dist = Vector2(x, z).length()
	var mountain = max(0, 1.0 - dist / 95.0)
	var peak = mountain * mountain * 58.0
	var ridge = 0.0
	if dist > 30 and dist < 80:
		ridge = max(0, 1.0 - abs(dist - 50) / 20.0) * 12.0 * max(0, sin(x * 0.25 + z * 0.18))
	var detail = detail_noise.get_noise_2d(x, z) * 1.2
	return raw * 6.0 + peak + ridge + detail

func terrain_color(h: float, nx: float, nz: float) -> Color:
	var slope = _compute_slope(h, nx, nz)
	if slope > 0.85:
		return Color(0.35, 0.33, 0.28)
	if h < 3.0:
		return Color(0.25, 0.42, 0.2)
	if h < 12.0:
		return Color(0.3, 0.48, 0.22)
	if h < 25.0:
		return Color(0.32, 0.4, 0.27)
	return Color(0.42, 0.38, 0.32).lerp(Color(0.6, 0.55, 0.5), min(1, (h - 25) / 30))

func _compute_slope(h: float, x: float, z: float) -> float:
	var d = 0.5
	var dx = (h(x + d, z) - h(x - d, z)) / (d * 2)
	var dz = (h(x, z + d) - h(x, z - d)) / (d * 2)
	return sqrt(dx * dx + dz * dz)

func _generate():
	_terrain()
	_trees()
	_ground_cover()
	_water()
	_portals()
	_buildings()
	_roads()
	_environment()

# =================== TERRAIN ===================

func _terrain():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var res = 150
	var size = 350.0
	var half = size / 2.0
	var step = size / res

	for z in range(res + 1):
		for x in range(res + 1):
			var wx = x * step - half
			var wz = z * step - half
			var y = h(wx, wz)
			var n = _terrain_normal(wx, wz)
			var col = terrain_color(y, wx, wz)
			st.set_color(col)
			st.set_normal(n)
			st.set_uv(Vector2(x / float(res), z / float(res)))
			st.set_uv2(Vector2(wx * 0.1, wz * 0.1))
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
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mi.material_override = mat
	add_child(mi)
	mi.owner = self

	var body = StaticBody3D.new()
	body.name = "TerrainBody"
	var shape = CollisionShape3D.new()
	var faces = mesh.get_faces()
	if faces.size() > 0:
		shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	shape.owner = body
	mi.add_child(body)
	body.owner = self

func _terrain_normal(x: float, z: float) -> Vector3:
	var d = 0.5
	var h_xz = h(x, z)
	var dx = Vector3(1, h(x + d, z) - h_xz, 0).normalized()
	var dz = Vector3(0, h(x, z + d) - h_xz, 1).normalized()
	return dx.cross(dz).normalized()

# =================== TREES ===================

func _trees():
	var res = 80
	var size = 300.0
	var half = size / 2.0
	var step = size / res
	for z in range(res):
		for x in range(res):
			var wx = x * step - half + randf_range(-1, 1)
			var wz = z * step - half + randf_range(-1, 1)
			var dist = Vector2(wx, wz).length()
			if dist < 15 or dist > 130:
				continue
			var y = h(wx, wz)
			if y < 1 or y > 30:
				continue
			var tn = tree_noise.get_noise_2d(wx, wz)
			if tn > 0.15:
				_make_tree(Vector3(wx, y, wz), y)

func _make_tree(pos: Vector3, ground_h: float):
	var root = Node3D.new()
	root.position = pos

	if _has_models and _tree_packed:
		var n3: Node3D = _tree_packed.instantiate() as Node3D
		if n3 != null:
			n3.owner = root
			var s = randf_range(0.6, 1.2)
			n3.scale = Vector3(s, s, s)
			n3.rotation.y = randf_range(0, TAU)
			root.add_child(n3)
	else:
		var h = randf_range(2.5, 6.0)
		var r = randf_range(0.12, 0.25)

		var trunk = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = r * 0.7
		cyl.bottom_radius = r
		cyl.height = h
		trunk.mesh = cyl
		trunk.position = Vector3(0, h / 2, 0)
		var tm = StandardMaterial3D.new()
		tm.albedo_color = Color(0.3, 0.2, 0.12).lerp(Color(0.4, 0.28, 0.15), randf())
		tm.roughness = 0.95
		trunk.material_override = tm

		var crown = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = randf_range(1.2, 2.5)
		sphere.height = randf_range(2.5, 4.5)
		crown.mesh = sphere
		crown.position = Vector3(0, h + 1.0, 0)
		var cm = StandardMaterial3D.new()
		var g = randf_range(0.2, 0.45)
		cm.albedo_color = Color(0.1, g, 0.08).lerp(Color(0.15, 0.35, 0.1), randf())
		cm.roughness = 0.8
		crown.material_override = cm

		root.add_child(trunk)
		trunk.owner = root
		root.add_child(crown)
		crown.owner = root
		root.rotation.y = randf_range(0, TAU)
		var s = randf_range(0.7, 1.3)
		root.scale = Vector3(s, s, s)

	add_child(root)
	root.owner = self

# =================== GROUND COVER ===================

func _ground_cover():
	if not _has_models:
		return
	var res := 40
	var size := 300.0
	var half := size / 2.0
	var step := size / res
	for z in range(res):
		for x in range(res):
			var wx := x * step - half + randf_range(-2, 2)
			var wz := z * step - half + randf_range(-2, 2)
			var dist := Vector2(wx, wz).length()
			if dist < 20 or dist > 125:
				continue
			var y := h(wx, wz)
			if y < 1.5 or y > 20:
				continue
			var val := tree_noise.get_noise_2d(wx + 50, wz + 50)
			if val > 0.3:
				var which: PackedScene = _bush_packed if val > 0.4 else _rock_packed
				if which == null:
					continue
				var n3: Node3D = which.instantiate() as Node3D
				if n3 == null:
					continue
				var s := randf_range(0.3, 0.7) if which == _bush_packed else randf_range(0.5, 1.0)
				n3.scale = Vector3(s, s, s)
				n3.rotation.y = randf_range(0, TAU)
				n3.position = Vector3(wx, y, wz)
				add_child(n3)
				n3.owner = self

# =================== WATER ===================

func _water():
	var water = MeshInstance3D.new()
	water.name = "Water"
	var plane = PlaneMesh.new()
	plane.size = Vector2(350, 350)
	plane.subdivide_depth = 20
	plane.subdivide_width = 20
	water.mesh = plane
	water.position = Vector3(0, -0.5, 0)
	var wm = StandardMaterial3D.new()
	wm.albedo_color = Color(0.15, 0.35, 0.45, 0.7)
	wm.metallic = 0.4
	wm.roughness = 0.2
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = wm
	add_child(water)
	water.owner = self

# =================== ROADS ===================

func _roads():
	var segments = [
		[Vector3(-10, 2, 120), Vector3(0, 3, 95), Vector3(15, 4, 75)],
		[Vector3(15, 4, 75), Vector3(35, 5, 55)],
		[Vector3(15, 4, 75), Vector3(80, 7, 25)],
		[Vector3(15, 4, 75), Vector3(-65, 4, 20)],
		[Vector3(15, 4, 75), Vector3(20, 3, -55)],
	]
	var rm = StandardMaterial3D.new()
	rm.albedo_color = Color(0.5, 0.45, 0.35)
	rm.roughness = 0.95
	for seg in segments:
		for i in range(len(seg) - 1):
			var a = seg[i]
			var b = seg[i + 1]
			var mid = (a + b) / 2
			var len = a.distance_to(b)
			var dir = (b - a).normalized()
			var up = Vector3.UP
			var right = dir.cross(up).normalized()
			var road = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(2.5, 0.15, len)
			road.mesh = box
			road.position = mid + Vector3(0, 0.1, 0)
			road.look_at(b)
			road.material_override = rm
			add_child(road)
			road.owner = self

# =================== PORTALS ===================

func _concrete():
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.53, 0.5)
	m.roughness = 0.85
	return m

func _red():
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.18, 0.12)
	m.roughness = 0.7
	return m

func _dark():
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.06, 0.05)
	m.roughness = 0.95
	return m

var _fence_packed: PackedScene

func _make_portal(name: String, pos: Vector3, rot: float, title: String, info: String):
	var root = Node3D.new()
	root.name = name
	root.position = pos
	root.rotation.y = rot
	add_child(root)
	root.owner = self

	if not _fence_packed:
		var fp := "res://models/glb/factory_kit/fence.glb"
		if ResourceLoader.exists(fp):
			_fence_packed = load(fp)
		elif FileAccess.file_exists(fp):
			_fence_packed = _load_glb(fp)
	if _fence_packed:
		for side in [-1, 1]:
			var n3: Node3D = _fence_packed.instantiate() as Node3D
			if n3 == null:
				continue
			n3.scale = Vector3(2, 2, 2)
			n3.position = Vector3(side * 6, 0, -1)
			n3.rotation.y = 0
			root.add_child(n3)
			n3.owner = root

	var tunnel = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 4.0
	cyl.bottom_radius = 4.5
	cyl.height = 10.0
	tunnel.mesh = cyl
	tunnel.position = Vector3(0, 3.5, -5)
	tunnel.material_override = _concrete()
	root.add_child(tunnel)
	tunnel.owner = self

	var inner = MeshInstance3D.new()
	var icyl = CylinderMesh.new()
	icyl.top_radius = 3.0
	icyl.bottom_radius = 3.0
	icyl.height = 12.0
	inner.mesh = icyl
	inner.position = Vector3(0, 2.0, -6)
	inner.material_override = _dark()
	root.add_child(inner)
	inner.owner = self

	var frame = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(8, 5.5, 1.5)
	frame.mesh = box
	frame.position = Vector3(0, 3.5, 1)
	frame.material_override = _concrete()
	root.add_child(frame)
	frame.owner = self

	var arch_r = MeshInstance3D.new()
	var abox = BoxMesh.new()
	abox.size = Vector3(1, 4.5, 1)
	arch_r.mesh = abox
	arch_r.position = Vector3(-4, 5, 0)
	arch_r.material_override = _concrete()
	root.add_child(arch_r)
	arch_r.owner = self

	var arch_l = arch_r.duplicate()
	arch_l.position.x = 4
	root.add_child(arch_l)
	arch_l.owner = self

	var sign = MeshInstance3D.new()
	var sbox = BoxMesh.new()
	sbox.size = Vector3(3.5, 1.2, 0.1)
	sign.mesh = sbox
	sign.position = Vector3(0, 7.5, 2.5)
	sign.material_override = _red()
	root.add_child(sign)
	sign.owner = self

	var light = OmniLight3D.new()
	light.name = "PortalLight"
	light.position = Vector3(0, 5, 0)
	light.light_energy = 0.8
	light.light_color = Color(1, 0.6, 0.2)
	light.omni_range = 8
	root.add_child(light)
	light.owner = self

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
	area.collision_layer = 2
	area.collision_mask = 0

func _portals():
	_make_portal("Portal1_South", Vector3(35, 5, 55), 0.2,
		"1번 갱도 - South Portal",
		"2006.10.09 - 1차 핵실험\n동쪽 갱도, 입구에서 1km 내부\n추정 폭발력 < 1kt | 상태: 폐쇄/붕괴\n2018.5.24 폭파 폐기")
	_make_portal("Portal2_East", Vector3(80, 7, 25), -0.4,
		"2번 갱도 - East Portal",
		"4차(2016.1.6) 5차(2016.9.9) 6차(2017.9.3) 핵실험\n6차: 규모 6.3 | 50-250kt (역대 최대)\n2018.5.24 폭파 폐기\n2021년 이후 복구 활동 감지")
	_make_portal("Portal3_West", Vector3(-65, 4, 20), 0.7,
		"3번 갱도 - West Portal",
		"2차(2009.5.25) 3차(2013.2.12) 핵실험\n2차: 4-6kt | 3차: 6-7kt\n매설심도 약 490m\n2018.5.24 폭파 폐기")
	_make_portal("Portal4_North", Vector3(20, 2, -55), 3.0,
		"4번 갱도 - North Portal",
		"신규 갱도 - 핵실험 사용 이력 없음\n2022년 이후 복구 활동 다수 관측\n7차 핵실험 가능성 지속 제기\n상태: 사용 준비 완료 추정")

# =================== BUILDINGS ===================

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
	rbox.size = Vector3(size.x + 1.2, 0.3, size.z + 1.2)
	roof.mesh = rbox
	roof.position = Vector3(0, size.y + 0.15, 0)
	var rm = StandardMaterial3D.new()
	rm.albedo_color = Color(0.35, 0.3, 0.25)
	rm.roughness = 0.9
	roof.material_override = rm
	root.add_child(roof)
	roof.owner = self

	for face in [-1, 1]:
		for i in [0, 1]:
			var window = MeshInstance3D.new()
			var wbox = BoxMesh.new()
			wbox.size = Vector3(1.4, 1.6, 0.05)
			window.mesh = wbox
			var xoff = (sign(face) * size.x / 2) + (face * 0.03)
			window.position = Vector3(xoff, size.y * 0.55, (i - 0.5) * size.z * 0.4)
			var wm = StandardMaterial3D.new()
			wm.albedo_color = Color(0.4, 0.6, 0.8)
			wm.emission_enabled = true
			wm.emission = Color(0.4, 0.6, 0.8)
			wm.emission_energy_multiplier = 0.3
			window.material_override = wm
			root.add_child(window)
			window.owner = self

	var door = MeshInstance3D.new()
	var dbox = BoxMesh.new()
	dbox.size = Vector3(1.8, 2.5, 0.1)
	door.mesh = dbox
	door.position = Vector3(0, 1.25, size.z / 2 + 0.05)
	var dm = StandardMaterial3D.new()
	dm.albedo_color = Color(0.2, 0.15, 0.1)
	dm.roughness = 0.9
	door.material_override = dm
	root.add_child(door)
	door.owner = self

	_decorate_building(root, size)

	var area = Area3D.new()
	area.name = "Interactable"
	area.position = Vector3(0, 2, size.z / 2 + 2.5)
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
	area.collision_layer = 2
	area.collision_mask = 0

func _decorate_building(parent: Node3D, size: Vector3):
	var paths := [
		"res://models/glb/factory_kit/oil-drum.glb",
		"res://models/glb/factory_kit/box-small.glb",
	]
	for p in paths:
		var ps: PackedScene
		if ResourceLoader.exists(p):
			ps = load(p) as PackedScene
		elif FileAccess.file_exists(p):
			ps = _load_glb(p)
		if ps == null:
			continue
		var count := randi() % 4
		for i in range(count):
			var n3: Node3D = ps.instantiate() as Node3D
			if n3 == null:
				continue
			var s := randf_range(0.5, 1.0)
			n3.scale = Vector3(s, s, s)
			n3.rotation.y = randf_range(0, TAU)
			n3.position = Vector3(
				randf_range(-size.x * 0.4, size.x * 0.4),
				0,
				randf_range(-size.z * 0.3, size.z * 0.3)
			)
			parent.add_child(n3)
			n3.owner = self

func _buildings():
	_make_building("AdminBuilding", Vector3(-15, 8, 100), Vector3(14, 6, 10),
		"주행정동 (Main Admin Area)",
		"핵실험장 주요 행정/지휘 시설\n2층 본부 건물 + 지원시설\n차량기지, 숙소, 창고 포함\n상주인원 수백 명 규모")
	_make_building("GuardPost", Vector3(40, 4, 80), Vector3(6, 3, 5),
		"경비초소 (Guard Post)",
		"진입로 검문소 및 경비병력 숙소\n출입 통제 및 보안 담당\n차량 및 인원 검문")
	_make_building("ObservationPost", Vector3(25, 18, 60), Vector3(5, 3, 5),
		"관측소 (Observation Post)",
		"핵실험 관측 및 계측 시설\n만탑산 남측 능선에 위치\n지진파/방사능 모니터링 장비")
	_make_building("SupportArea", Vector3(50, 7, 95), Vector3(10, 4, 8),
		"남측 지원구역 (South Support Area)",
		"장비 보관 및 정비 시설\n건설 자재 적치장\n차량 운행 기지 및 주차장")

# =================== ENVIRONMENT ===================

func _environment():
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(-0.55, 0.7, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 0.5
	add_child(sun)
	sun.owner = self

	var ambient = DirectionalLight3D.new()
	ambient.name = "AmbientFill"
	ambient.light_energy = 0.12
	ambient.light_color = Color(0.5, 0.6, 0.85)
	ambient.rotation = Vector3(0.3, -0.5, 0)
	add_child(ambient)
	ambient.owner = self

	var env = WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var e = Environment.new()
	e.tonemap_mode = 3
	e.ambient_light_color = Color(0.3, 0.35, 0.45)
	e.ambient_light_energy = 0.3

	e.glow_enabled = true
	e.glow_levels = 1
	e.glow_intensity = 0.05
	e.glow_strength = 1.0
	e.glow_bloom = 0.1

	var fog_mat = FogMaterial.new()
	fog_mat.density = 0.003
	fog_mat.albedo_color = Color(0.65, 0.72, 0.85)
	e.fog_enabled = true
	e.fog_material = fog_mat

	var sky_path := "res://textures/skyboxes/skybox-day.png"
	if FileAccess.file_exists(sky_path):
		var tex := load(sky_path) as Texture2D
		if tex:
			var pano := PanoramaSkyMaterial.new()
			pano.panorama = tex
			pano.filtering_enabled = false
			var sky := Sky.new()
			sky.sky_material = pano
			e.background_mode = Environment.BG_SKY
			e.sky = sky
			e.background_color = Color(0.4, 0.55, 0.85)
		else:
			_fallback_sky(e)
	else:
		_fallback_sky(e)

	env.environment = e
	add_child(env)
	env.owner = self

func _fallback_sky(e: Environment):
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.35, 0.55, 0.85)
	sky.sky_horizon_color = Color(0.65, 0.72, 0.82)
	sky.ground_bottom_color = Color(0.2, 0.22, 0.2)
	sky.ground_horizon_color = Color(0.4, 0.42, 0.38)
	sky.sun_angle_max = 0.5
	var s := Sky.new()
	s.sky_material = sky
	e.background_mode = Environment.BG_SKY
	e.sky = s
