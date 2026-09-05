extends Node3D
class_name ChapelWorld

## A ruined little church, built from blunt geometry and dirty, low-resolution surfaces.
## God was made in our image. That was the original sin.

var pickups: Dictionary = {}
var altar: Node3D
var exit_door: Node3D
var idol: Node3D

var _rng := RandomNumberGenerator.new()
var _materials: Dictionary = {}
var _lamps: Array[OmniLight3D] = []
var _flames: Array[MeshInstance3D] = []
var _seal_bases: Dictionary = {}
var _god_light: OmniLight3D
var _exit_light: OmniLight3D
var _door_pivot: Node3D
var _door_body: StaticBody3D
var _environment: Environment
var _awake := false
var _opened := false
var _built := false
var _idol_rest := Vector3.ZERO
var _fissures: Array[MeshInstance3D] = []
var _eyes: Array[MeshInstance3D] = []


func build() -> void:
	if _built:
		return
	_built = true
	_rng.seed = 613031
	_make_materials()
	_make_environment()
	_make_shell()
	_make_pews()
	_make_architecture()
	_make_altar()
	_make_idol()
	_make_shrines()
	_make_exit()
	_make_details()


func _make_materials() -> void:
	_materials["wall"] = _dirty_material(Color("66645b"), "plaster", 31)
	_materials["dark_wall"] = _dirty_material(Color("41443f"), "plaster", 73)
	_materials["floor"] = _dirty_material(Color("4d504b"), "stone", 40)
	_materials["stone"] = _dirty_material(Color("78766a"), "stone", 83)
	_materials["wood"] = _dirty_material(Color("473a2c"), "wood", 14)
	_materials["dark_wood"] = _dirty_material(Color("28211a"), "wood", 17)
	_materials["rust"] = _dirty_material(Color("514038"), "metal", 81)
	_materials["bone"] = _dirty_material(Color("b0a898"), "plaster", 64)
	_materials["cloth"] = _dirty_material(Color("171c1b"), "cloth", 23)
	_materials["red"] = _dirty_material(Color("522a29"), "metal", 32)
	_materials["black"] = _plain(Color("0a1010"))
	_materials["blood"] = _plain(Color("391714"))
	_materials["gold"] = _dirty_material(Color("817454"), "metal", 33)
	_materials["wax"] = _plain(Color("bcb5a2"))
	_materials["paper"] = _dirty_material(Color("aaa48f"), "paper", 19)
	_materials["chalk"] = _plain(Color("a19f87"))
	_materials["flame"] = _glow(Color("f6bd6c"), 2.8)
	_materials["seal"] = _glow(Color("e8b57d"), 0.85)
	_materials["fissure"] = _glow(Color("c4281d"), 2.0)
	_materials["exit_sign"] = _glow(Color("e66b55"), 1.7)
	_materials["tv"] = _glow(Color("8bb5ad"), 0.9)
	_materials["window"] = _glow(Color("586e77"), 0.22)


func _plain(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.94
	return mat


func _glow(color: Color, strength: float) -> StandardMaterial3D:
	var mat := _plain(color)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = strength
	return mat


func _dirty_material(color: Color, kind: String, seed_value: int) -> StandardMaterial3D:
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = seed_value
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var grain := noise_rng.randf_range(-0.12, 0.12)
			var stain := sin(float(x) * 0.18 + sin(float(y) * 0.22)) * 0.055
			stain += cos(float(y) * 0.12 + float(x) * 0.19) * 0.075
			var shade := 0.87 + grain + stain
			if kind == "wood":
				shade += sin(float(x) * 1.75 + sin(float(y) * 0.09)) * 0.15
				if x % 16 == 0:
					shade *= 0.40
			elif kind == "stone":
				if x < 1 or y < 1 or x > 62 or y > 62:
					shade *= 0.56
			elif kind == "plaster":
				if sin(float(x) * 0.37 + cos(float(y) * 0.07) * 5.0) > 0.98:
					shade *= 0.48
				if y > 47:
					shade *= 0.86
			elif kind == "cloth":
				shade += sin(float(x) * 0.5) * 0.18
			elif kind == "metal":
				if noise_rng.randf() < 0.055:
					shade *= 0.45
			elif kind == "paper":
				if y % 7 == 0 and x > 7 and x < 53:
					shade *= 0.74
			img.set_pixel(x, y, Color(color.r * shade, color.g * shade, color.b * shade, 1.0))
	var mat := _plain(Color.WHITE)
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat


func _make_environment() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("151f21")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("82968e")
	_environment.ambient_light_energy = 0.29
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.fog_enabled = true
	_environment.fog_light_color = Color("26312f")
	_environment.fog_light_energy = 0.62
	_environment.fog_density = 0.016
	_environment.fog_sky_affect = 0.0
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ChapelAir"
	world_environment.environment = _environment
	add_child(world_environment)
	var moon := DirectionalLight3D.new()
	moon.name = "MoonThroughRoof"
	moon.rotation_degrees = Vector3(-63.0, -21.0, 0.0)
	moon.light_color = Color("879eaa")
	moon.light_energy = 0.30
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 38.0
	add_child(moon)
	for z in [13.0, 1.0, -11.0]:
		var light := _light(self, Vector3(0.0, 5.5, z), Color("70867e"), 0.70, 13.0)
		light.omni_attenuation = 1.8
		_lamps.append(light)


func _make_shell() -> void:
	_box(self, "Foundation", Vector3(0, -0.3, 0), Vector3(23, 0.6, 45), "floor", true)
	for x in range(-5, 6):
		for z in range(-11, 11):
			var tile := _box(self, "Flagstone", Vector3(float(x) * 2.0, 0.006, float(z) * 2.0 + 1.0), Vector3(1.97, 0.035, 1.97), "floor")
			tile.rotation.y = PI * float(_rng.randi_range(0, 3)) * 0.5
	_box(self, "WestWall", Vector3(-11.25, 4.1, 0), Vector3(0.5, 8.2, 45), "wall", true)
	_box(self, "EastWall", Vector3(11.25, 4.1, 0), Vector3(0.5, 8.2, 45), "wall", true)
	_box(self, "ApseWall", Vector3(0, 4.1, -22.25), Vector3(23, 8.2, 0.5), "dark_wall", true)
	_box(self, "RearWallLeft", Vector3(-6.4, 4.1, 22.25), Vector3(9.3, 8.2, 0.5), "wall", true)
	_box(self, "RearWallRight", Vector3(6.4, 4.1, 22.25), Vector3(9.3, 8.2, 0.5), "wall", true)
	_box(self, "ExitLintelWall", Vector3(0, 5.9, 22.25), Vector3(3.6, 4.6, 0.5), "wall", true)
	_box(self, "RoofDarkness", Vector3(0, 8.5, 0), Vector3(23, 0.3, 45), "dark_wood")
	for side in [-1.0, 1.0]:
		_box(self, "WaterDamagedWainscot", Vector3(side * 10.92, 0.93, 0), Vector3(0.12, 1.85, 44), "dark_wall")
		_box(self, "DadoRail", Vector3(side * 10.82, 1.92, 0), Vector3(0.20, 0.10, 44), "wood")
		_box(self, "Skirting", Vector3(side * 10.84, 0.19, 0), Vector3(0.23, 0.3, 44), "dark_wood")
		for z in range(-20, 23, 4):
			_box(self, "WallPanelSeam", Vector3(side * 10.82, 0.97, float(z)), Vector3(0.2, 1.78, 0.045), "wood")
	# The path remains bare. Rust-colored runners end before the altar.
	_box(self, "AisleRunner", Vector3(0, 0.041, 2.5), Vector3(3.3, 0.012, 28.0), "red")
	for x in [-1.49, 1.49]:
		_box(self, "RunnerFadedBorder", Vector3(x, 0.049, 2.5), Vector3(0.04, 0.008, 27.8), "gold")
	for z in range(-10, 17, 3):
		_box(self, "RunnerSeam", Vector3(0, 0.05, float(z)), Vector3(3.15, 0.006, 0.018), "dark_wood")


func _make_pews() -> void:
	for side in [-1.0, 1.0]:
		for row in range(6):
			var z := 12.0 - float(row) * 4.0
			var pew := Node3D.new()
			pew.name = "Pew_%s_%s" % [side, row]
			pew.position = Vector3(side * 5.05, 0, z)
			add_child(pew)
			_box(pew, "Seat", Vector3(0, 0.55, 0), Vector3(4.6, 0.18, 0.93), "wood", true)
			var back := _box(pew, "Back", Vector3(0, 1.04, 0.48), Vector3(4.6, 0.88, 0.14), "wood", true)
			back.rotation.x = -0.08
			_box(pew, "BackCrest", Vector3(0, 1.50, 0.52), Vector3(4.74, 0.13, 0.22), "dark_wood")
			for edge in [-2.30, 2.30]:
				_box(pew, "CarvedEnd", Vector3(edge, 0.59, 0.03), Vector3(0.20, 1.16, 1.11), "dark_wood", true)
				_box(pew, "EndCap", Vector3(edge, 1.19, 0.02), Vector3(0.26, 0.12, 1.22), "wood")
				_box(pew, "PewFoot", Vector3(edge, 0.13, 0), Vector3(0.40, 0.23, 1.2), "dark_wood")
			for offset in [-1.7, -0.85, 0.0, 0.85, 1.7]:
				_box(pew, "BackPanelJoint", Vector3(offset, 1.04, 0.567), Vector3(0.025, 0.71, 0.009), "black")
			if row % 2 == 0:
				var book := _box(pew, "AbandonedHymnal", Vector3(_rng.randf_range(-1.6, 1.6), 0.67, 0.0), Vector3(0.32, 0.06, 0.44), "black")
				book.rotation.y = _rng.randf_range(-0.5, 0.5)


func _make_architecture() -> void:
	for z in [-17.0, -9.0, -1.0, 7.0, 15.0]:
		_box(self, "RoofTruss", Vector3(0, 7.4, z), Vector3(22, 0.38, 0.42), "dark_wood")
		for side in [-1.0, 1.0]:
			var pos := Vector3(side * 9.75, 0, z)
			_box(self, "PillarPlinth", pos + Vector3(0, 0.24, 0), Vector3(0.98, 0.48, 0.95), "stone", true)
			_box(self, "PillarShaft", pos + Vector3(0, 3.6, 0), Vector3(0.52, 6.4, 0.54), "wall", true)
			_box(self, "PillarCapital", pos + Vector3(0, 6.9, 0), Vector3(0.97, 0.4, 0.86), "stone")
			_beam(self, Vector3(side * 9.70, 5.8, z), Vector3(side * 7.1, 7.4, z), 0.22, "dark_wood")
			_beam(self, Vector3(side * 9.6, 7.4, z), Vector3(side * 3.8, 8.2, z), 0.22, "dark_wood")
	for x in [-7.0, -3.5, 0.0, 3.5, 7.0]:
		_box(self, "LongRoofTimber", Vector3(x, 8.16, 0), Vector3(0.22, 0.25, 44), "wood")
	for side in [-1.0, 1.0]:
		for z in [-13.0, -5.0, 3.0, 11.0]:
			var window := Node3D.new()
			window.name = "BlindClerestoryWindow"
			window.position = Vector3(side * 10.93, 4.9, z)
			window.rotation.y = -side * PI * 0.5
			add_child(window)
			_box(window, "WindowRecess", Vector3.ZERO, Vector3(2.16, 3.34, 0.08), "black")
			_box(window, "OpaqueGlass", Vector3(0, 0, 0.045), Vector3(1.78, 2.95, 0.04), "window")
			for x in [-1.01, 0.0, 1.01]:
				_box(window, "LeadMullion", Vector3(x, 0, 0.10), Vector3(0.10, 3.4, 0.12), "dark_wood")
			for y in [-1.65, -0.52, 0.56, 1.65]:
				_box(window, "LeadTransom", Vector3(0, y, 0.10), Vector3(2.16, 0.11, 0.12), "dark_wood")
			for board_index in range(2):
				var board := _box(window, "NailedBoard", Vector3(0, -0.66 + float(board_index) * 1.0, 0.19), Vector3(2.30, 0.28, 0.09), "wood")
				board.rotation.z = -0.15 * side + float(board_index) * 0.24
	# A suspended cage chandelier frames the god without obscuring the sight line.
	for z in [8.0, -3.0]:
		_cylinder(self, "ChandelierCable", Vector3(0, 7.05, z), 0.015, 2.7, "rust", 5)
		_ring(self, Vector3(0, 5.78, z), 1.14, 0.045, "rust", false)
		for i in range(8):
			var a := float(i) * TAU / 8.0
			var candle_pos := Vector3(cos(a) * 1.14, 5.78, z + sin(a) * 1.14)
			_candle(self, candle_pos, 0.35, false)
			_beam(self, Vector3(0, 6.5, z), candle_pos, 0.018, "rust")


func _make_altar() -> void:
	altar = Node3D.new()
	altar.name = "AltarInteraction"
	altar.position = Vector3(0, 1.3, -17)
	add_child(altar)
	# A low ritual platform is decorative, keeping floor navigation smooth.
	_box(self, "ApsePlatform", Vector3(0, 0.06, -18.8), Vector3(12.0, 0.12, 5.8), "stone")
	_box(altar, "AltarSlab", Vector3(0, -0.15, 0), Vector3(4.3, 0.32, 1.9), "stone", true)
	_box(altar, "AltarBody", Vector3(0, -0.75, 0.1), Vector3(3.4, 0.95, 1.42), "dark_wall", true)
	_box(altar, "AltarFrontInset", Vector3(0, -0.70, 0.83), Vector3(2.6, 0.67, 0.025), "black")
	_box(altar, "AltarShroud", Vector3(0, 0.018, 0.22), Vector3(1.3, 0.014, 1.40), "red")
	_box(altar, "FallenShroud", Vector3(0, -0.48, 0.971), Vector3(1.3, 1.0, 0.018), "red")
	for i in range(3):
		var x := float(i - 1) * 0.72
		_ring(altar, Vector3(x, 0.046, 0.22), 0.235, 0.018, "gold", false)
		_box(altar, "OfferingSlot", Vector3(x, 0.042, 0.22), Vector3(0.30, 0.008, 0.045), "black")
	for side in [-1.0, 1.0]:
		for i in range(3):
			_candle(altar, Vector3(side * (1.33 + float(i) * 0.25), 0.02, -0.25), 0.22 + float(i) * 0.15, i == 1)
		_box(self, "PrayerRail", Vector3(side * 4.30, 0.93, -14.4), Vector3(3.85, 0.12, 0.28), "wood", true)
		for x in [2.45, 3.36, 4.30, 5.22, 6.1]:
			_box(self, "PrayerRailSpindle", Vector3(side * x, 0.49, -14.4), Vector3(0.09, 0.89, 0.11), "dark_wood")
		_box(self, "Kneeler", Vector3(side * 4.3, 0.16, -13.87), Vector3(3.8, 0.25, 0.58), "red")
	_label(self, "WE MADE HIM LISTEN", Vector3(0, 1.0, -21.92), 45, 0.016, Color("888174"))
	_label(altar, "RETURN WHAT YOU TOOK", Vector3(0, -0.7, 0.86), 32, 0.009, Color("b1a391"))
	# Uneven altar candles make a human, long-abandoned presence.
	for i in range(10):
		var side := -1.0 if i < 5 else 1.0
		var x := side * _rng.randf_range(3.0, 5.5)
		_candle(self, Vector3(x, 0.14, _rng.randf_range(-20.9, -18.0)), _rng.randf_range(0.15, 0.47), false)


func _make_idol() -> void:
	# The corpse hangs above the altar, with the halo broken by its own silhouette.
	idol = Node3D.new()
	idol.name = "TheDeadGod"
	idol.position = Vector3(0, 4.85, -19.4)
	_idol_rest = idol.position
	add_child(idol)
	_box(self, "BlackCrossUpright", Vector3(0, 4.4, -21.55), Vector3(0.40, 7.0, 0.26), "dark_wood")
	var cross := _box(self, "BrokenCrossbeam", Vector3(-0.25, 5.8, -21.50), Vector3(6.0, 0.35, 0.3), "dark_wood")
	cross.rotation.z = 0.045
	# Every halo ring has missing teeth and a different wound.
	for ring_index in range(3):
		var radius := 1.0 + float(ring_index) * 0.31
		for segment in range(28):
			if (segment + ring_index * 4) % 13 < 2:
				continue
			var a := float(segment) * TAU / 28.0
			var b := float(segment + 1) * TAU / 28.0
			var p1 := Vector3(cos(a) * radius, 1.12 + sin(a) * radius, -0.35)
			var p2 := Vector3(cos(b) * radius, 1.12 + sin(b) * radius, -0.35)
			_beam(idol, p1, p2, 0.032 + float(ring_index) * 0.006, "gold")
	for i in range(13):
		var angle := float(i) * TAU / 13.0
		_beam(idol, Vector3(cos(angle) * 1.68, 1.12 + sin(angle) * 1.68, -0.36), Vector3(cos(angle) * 1.91, 1.12 + sin(angle) * 1.91, -0.36), 0.025, "gold")
	var torso := _cylinder(idol, "HollowTorso", Vector3(0, -0.10, 0), 0.51, 1.74, "bone", 7)
	(torso.mesh as CylinderMesh).top_radius = 0.62
	(torso.mesh as CylinderMesh).bottom_radius = 0.25
	torso.rotation.z = -0.075
	_sphere(idol, "Pelvis", Vector3(0.09, -0.96, 0), Vector3(0.61, 0.51, 0.39), "bone", 8, 5)
	_beam(idol, Vector3(-0.05, 0.67, 0), Vector3(-0.03, 1.15, 0), 0.16, "bone")
	var head := _sphere(idol, "FaceWithoutMercy", Vector3(-0.03, 1.32, 0.14), Vector3(0.68, 0.96, 0.52), "bone", 9, 6)
	head.rotation.z = -0.14
	# One black vertical rupture, and a wet red light impossibly far behind it.
	var wound := _box(idol, "TheWound", Vector3(-0.016, 1.32, 0.40), Vector3(0.12, 0.66, 0.026), "black")
	wound.rotation.z = -0.13
	var red_line := _box(idol, "UnclosedEye", Vector3(-0.005, 1.32, 0.419), Vector3(0.028, 0.50, 0.008), "fissure")
	red_line.rotation.z = -0.13
	_fissures.append(red_line)
	for side in [-1.0, 1.0]:
		var shoulder := Vector3(side * 0.48, 0.54, 0)
		var elbow := Vector3(side * 1.47, 0.86 - side * 0.14, 0.04)
		var wrist := Vector3(side * 2.74, 0.65 - side * 0.2, 0.0)
		_beam(idol, shoulder, elbow, 0.21, "bone")
		_sphere(idol, "Elbow", elbow, Vector3(0.23, 0.23, 0.22), "bone", 7, 4)
		_beam(idol, elbow, wrist, 0.145, "bone")
		_sphere(idol, "Palm", wrist + Vector3(side * 0.1, -0.07, 0), Vector3(0.30, 0.16, 0.15), "bone", 6, 4)
		for finger in range(4):
			var start := wrist + Vector3(side * (0.15 + float(finger) * 0.045), -0.09, float(finger - 2) * 0.032)
			_beam(idol, start, start + Vector3(side * 0.14, -0.25 - float(finger % 2) * 0.06, 0.04), 0.028, "bone")
		var hip := Vector3(side * 0.18 + 0.08, -1.05, 0)
		var knee := Vector3(side * 0.28 + 0.09, -2.02, 0.05)
		var foot := Vector3(side * 0.26 + 0.17, -2.91, 0.09)
		_beam(idol, hip, knee, 0.18, "bone")
		_beam(idol, knee, foot, 0.12, "bone")
		_sphere(idol, "DeadFoot", foot + Vector3(0, -0.10, 0.10), Vector3(0.19, 0.32, 0.37), "bone", 7, 4)
		# Ropes ascend diagonally from the wrists into the roof.
		_beam(self, idol.position + wrist, Vector3(side * 3.9, 8.30, -19.95), 0.022, "rust")
		_beam(self, idol.position + wrist + Vector3(0, 0, 0.02), Vector3(side * 6.4, 7.45, -20.8), 0.015, "rust")
	# The ribs feel hand-carved, and a deep gap replaces the heart.
	for i in range(5):
		var y := 0.43 - float(i) * 0.23
		for side in [-1.0, 1.0]:
			var rib := _box(idol, "ExposedRib", Vector3(side * 0.23, y, 0.39), Vector3(0.48 - float(i) * 0.044, 0.052, 0.072), "dark_wood")
			rib.rotation.z = side * 0.12
	var heart := _sphere(idol, "MissingHeart", Vector3(0, 0.14, 0.46), Vector3(0.29, 0.42, 0.05), "black", 8, 5)
	_eyes.append(heart)
	_make_torn_cloth(idol)
	_god_light = _light(self, Vector3(0, 4.6, -17.7), Color("c26842"), 1.35, 8.5)
	_god_light.omni_attenuation = 1.35
	_light(self, Vector3(0, 7.5, -20.5), Color("7d9797"), 1.85, 7.0)
	_label(self, "우리가 죽였다", Vector3(0, 3.9, -21.93), 74, 0.012, Color("6c302a"))
	_label(self, "GOD IS DEAD", Vector3(0, 7.68, -21.90), 55, 0.013, Color("b1a58d"))


func _make_torn_cloth(parent: Node3D) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for side in [-1.0, 1.0]:
		for strip in range(9):
			var x1 := -0.58 + float(strip) * 0.14
			var x2 := x1 + 0.18
			var bottom := -2.0 - _rng.randf_range(0.1, 1.12)
			var z: float = side * 0.30
			var start := vertices.size()
			vertices.append_array(PackedVector3Array([
				Vector3(x1, -0.42, z), Vector3(x2, -0.45, z),
				Vector3(x2 * 1.37, bottom + 0.25, z + 0.10),
				Vector3(x1 * 1.32, bottom, z + 0.04)]))
			uvs.append_array(PackedVector2Array([Vector2.ZERO, Vector2(1, 0), Vector2.ONE, Vector2(0, 1)]))
			for _i in range(4):
				normals.append(Vector3(0, 0, side))
			indices.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var cloth_mat: StandardMaterial3D = _materials["cloth"].duplicate()
	cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cloth := MeshInstance3D.new()
	cloth.name = "HumanPrayersMadeFlesh"
	cloth.mesh = mesh
	cloth.material_override = cloth_mat
	parent.add_child(cloth)
	for i in range(7):
		var x := _rng.randf_range(-0.45, 0.45)
		_beam(parent, Vector3(x, -0.4, 0.36), Vector3(x * 1.5, -_rng.randf_range(1.4, 2.6), 0.48), 0.025, "blood")


func _make_shrines() -> void:
	var positions := [Vector3(-8, 1.2, 8), Vector3(8, 1.2, 0), Vector3(-8, 1.2, -10)]
	var names := ["I  /  FAITH", "II  /  MERCY", "III  /  FORGIVENESS"]
	for i in range(3):
		var pos: Vector3 = positions[i]
		var shrine := Node3D.new()
		shrine.name = "Shrine_%d" % (i + 1)
		shrine.position = Vector3(pos.x, 0, pos.z)
		add_child(shrine)
		_box(shrine, "OfferingStone", Vector3(0, 0.53, 0), Vector3(1.25, 1.06, 1.35), "dark_wall", true)
		_box(shrine, "OfferingLedge", Vector3(0, 1.07, 0), Vector3(1.66, 0.12, 1.62), "stone")
		_box(shrine, "PedestalFront", Vector3(0, 0.62, 0.687), Vector3(0.8, 0.47, 0.016), "black")
		_label(shrine, "%02d" % (i + 1), Vector3(0, 0.66, 0.70), 48, 0.007, Color("b3a58c"))
		for offset in [-0.59, 0.59]:
			_candle(shrine, Vector3(offset, 1.14, -0.43), 0.32 + float(i) * 0.045, false)
		var seal := Node3D.new()
		seal.name = "Seal_%d" % (i + 1)
		seal.position = pos
		add_child(seal)
		var id := "seal_%d" % (i + 1)
		pickups[id] = seal
		_seal_bases[id] = pos
		_ring(seal, Vector3(0, 0.18, 0), 0.24, 0.032, "seal", true)
		_ring(seal, Vector3(0, 0.18, 0), 0.155, 0.013, "gold", true)
		_box(seal, "SealSpine", Vector3(0, 0.18, 0), Vector3(0.04, 0.36, 0.028), "seal")
		_box(seal, "SealCrossbar", Vector3(0, 0.25, 0), Vector3(0.28, 0.035, 0.026), "seal")
		var light := _light(shrine, Vector3(0, 1.65, 0.0), Color("e5a46c"), 1.8, 4.0)
		_lamps.append(light)
		_label(shrine, names[i], Vector3(0, 1.65, -0.58), 34, 0.007, Color("c9b79a"))
		# A nameless, blank devotional portrait stands behind each relic.
		var toward_wall := signf(pos.x)
		var portrait := Node3D.new()
		portrait.position = Vector3(toward_wall * 2.77, 2.9, 0)
		portrait.rotation.y = -toward_wall * PI * 0.5
		shrine.add_child(portrait)
		_box(portrait, "PortraitFrame", Vector3.ZERO, Vector3(1.56, 2.30, 0.12), "gold")
		_box(portrait, "BurntPortrait", Vector3(0, 0, 0.08), Vector3(1.32, 2.06, 0.02), "black")
		_sphere(portrait, "ErasedSaintFace", Vector3(0, 0.40, 0.10), Vector3(0.43, 0.59, 0.03), "dark_wall", 8, 5)
		_ring(portrait, Vector3(0, 0.47, 0.09), 0.41, 0.014, "gold", true)
		_box(portrait, "SaintRobe", Vector3(0, -0.39, 0.105), Vector3(0.65, 0.95, 0.025), "dark_wall")


func _make_exit() -> void:
	exit_door = Node3D.new()
	exit_door.name = "ExitInteraction"
	exit_door.position = Vector3(0, 1.5, 20.5)
	add_child(exit_door)
	_box(self, "DoorFrameL", Vector3(-1.65, 1.9, 22.02), Vector3(0.18, 3.8, 0.40), "rust", true)
	_box(self, "DoorFrameR", Vector3(1.65, 1.9, 22.02), Vector3(0.18, 3.8, 0.40), "rust", true)
	_box(self, "DoorFrameTop", Vector3(0, 3.71, 22.02), Vector3(3.5, 0.18, 0.4), "rust", true)
	_door_pivot = Node3D.new()
	_door_pivot.name = "ExitHinge"
	_door_pivot.position = Vector3(-1.55, -1.5, 1.44)
	exit_door.add_child(_door_pivot)
	var slab := _box(_door_pivot, "RedExitDoor", Vector3(1.55, 1.77, 0), Vector3(3.1, 3.54, 0.16), "red", true)
	_door_body = slab.get_child(0) as StaticBody3D
	for x in [0.73, 2.35]:
		_box(_door_pivot, "DoorInset", Vector3(x, 2.2, -0.085), Vector3(1.25, 2.18, 0.02), "dark_wood")
		_box(_door_pivot, "DoorInsetRed", Vector3(x, 2.2, -0.100), Vector3(1.11, 2.0, 0.018), "red")
	_box(_door_pivot, "DoorCentreSeam", Vector3(1.55, 1.76, -0.098), Vector3(0.028, 3.45, 0.018), "black")
	_box(_door_pivot, "PanicBar", Vector3(1.55, 1.2, -0.20), Vector3(2.36, 0.10, 0.13), "rust")
	_box(self, "ExitLightHousing", Vector3(0, 4.18, 21.96), Vector3(1.45, 0.48, 0.23), "black")
	var exit_label := _label(self, "E X I T", Vector3(0, 4.18, 21.815), 52, 0.0065, Color("f2a08c"))
	exit_label.rotation.y = PI
	var instruction := _label(self, "DO NOT BRING HIM OUT", Vector3(0, 2.64, 21.80), 39, 0.0065, Color("bfb4a0"))
	instruction.rotation.y = PI
	_exit_light = _light(self, Vector3(0, 3.6, 20.9), Color("d45840"), 1.0, 5.0)
	_box(self, "OutsideThreshold", Vector3(0, -0.1, 25.0), Vector3(5.0, 0.2, 7.0), "black", true)
	_box(self, "ExitDarknessLeft", Vector3(-2.45, 2.4, 25.0), Vector3(0.3, 4.8, 7.0), "black", true)
	_box(self, "ExitDarknessRight", Vector3(2.45, 2.4, 25.0), Vector3(0.3, 4.8, 7.0), "black", true)
	_box(self, "ExitDarknessRoof", Vector3(0, 4.8, 25.0), Vector3(5.0, 0.3, 7.0), "black")


func _make_details() -> void:
	# Analog monitoring station, still tuned to a congregation that no longer exists.
	var station := Node3D.new()
	station.name = "VHSMonitoringDesk"
	station.position = Vector3(7.6, 0, 17.65)
	station.rotation.y = -0.22
	add_child(station)
	_box(station, "DeskTop", Vector3(0, 0.94, 0), Vector3(2.6, 0.16, 1.15), "wood", true)
	for x in [-1.08, 1.08]:
		_box(station, "DeskLeg", Vector3(x, 0.45, 0), Vector3(0.13, 0.9, 0.91), "rust")
	_box(station, "TelevisionCase", Vector3(-0.49, 1.48, -0.05), Vector3(1.14, 0.91, 0.80), "dark_wood")
	_box(station, "TelevisionBezel", Vector3(-0.56, 1.49, 0.362), Vector3(0.83, 0.69, 0.04), "black")
	_box(station, "CathodeScreen", Vector3(-0.57, 1.49, 0.389), Vector3(0.71, 0.57, 0.016), "tv")
	for line in range(15):
		_box(station, "TelevisionScanline", Vector3(-0.57, 1.22 + float(line) * 0.038, 0.40), Vector3(0.70, 0.009, 0.002), "dark_wall")
	for y in [1.36, 1.67]:
		var knob := _cylinder(station, "TuningKnob", Vector3(-0.03, y, 0.395), 0.07, 0.045, "black", 8)
		knob.rotation.x = PI * 0.5
	_box(station, "VideoDeck", Vector3(0.63, 1.12, 0.15), Vector3(0.85, 0.20, 0.52), "black")
	_box(station, "TapeSlot", Vector3(0.62, 1.13, 0.421), Vector3(0.54, 0.04, 0.006), "rust")
	_box(station, "RedRecordLED", Vector3(0.96, 1.15, 0.423), Vector3(0.034, 0.018, 0.006), "fissure")
	for i in range(3):
		var cassette := _box(station, "VHSArchive", Vector3(0.61, 1.28 + float(i) * 0.066, 0.10), Vector3(0.48, 0.055, 0.31), "black")
		cassette.rotation.y = -0.06 + float(i) * 0.095
		_box(cassette, "TapeLabel", Vector3(0, 0.029, 0), Vector3(0.31, 0.007, 0.12), "paper")
	_label(station, "NO SIGNAL", Vector3(-0.57, 1.51, 0.411), 27, 0.0036, Color("202d2c"))
	_light(station, Vector3(-0.55, 1.6, 0.8), Color("8fb4ac"), 0.55, 4.0)
	var radio := Node3D.new()
	radio.position = Vector3(-7.8, 0, 17.3)
	radio.rotation.y = 0.14
	add_child(radio)
	_box(radio, "RadioCrate", Vector3(0, 0.33, 0), Vector3(1.65, 0.66, 0.99), "wood", true)
	_box(radio, "Radio", Vector3(0, 0.98, 0), Vector3(1.23, 0.62, 0.44), "dark_wood")
	_box(radio, "RadioGrille", Vector3(-0.20, 0.98, 0.23), Vector3(0.70, 0.46, 0.02), "black")
	for i in range(8):
		_box(radio, "RadioGrilleRib", Vector3(-0.49 + float(i) * 0.085, 0.98, 0.25), Vector3(0.018, 0.43, 0.014), "rust")
	_box(radio, "RadioDial", Vector3(0.38, 1.09, 0.235), Vector3(0.28, 0.13, 0.023), "seal")
	_beam(radio, Vector3(0.39, 1.3, -0.10), Vector3(0.60, 2.1, -0.19), 0.012, "rust")
	# Small readable wall inscriptions give the place an authored history.
	var notice := _label(self, "DO NOT ANSWER\nTHE SECOND VOICE", Vector3(-10.79, 2.71, 16.8), 49, 0.011, Color("b7ad95"))
	notice.rotation.y = PI * 0.5
	var graffiti := _label(self, "HE LEARNED\nOUR CRUELTY", Vector3(10.79, 2.8, -7.2), 62, 0.012, Color("632d27"))
	graffiti.rotation.y = -PI * 0.5
	# Debris never blocks traversal: paper, wax, and stains sit just above the floor.
	for i in range(44):
		var pos := Vector3(_rng.randf_range(-9.7, 9.7), 0.055, _rng.randf_range(-18, 19))
		if absf(pos.x) < 1.2 and pos.z > 10:
			continue
		var paper := _box(self, "DiscardedPrayer", pos, Vector3(_rng.randf_range(0.16, 0.33), 0.004, _rng.randf_range(0.23, 0.45)), "paper")
		paper.rotation.y = _rng.randf_range(-PI, PI)
	for i in range(18):
		var stain := _cylinder(self, "DriedWater", Vector3(_rng.randf_range(-9.5, 9.5), 0.047, _rng.randf_range(-20, 19)), _rng.randf_range(0.13, 0.50), 0.002, "black", 9)
		stain.scale.z = _rng.randf_range(0.36, 1.5)
	for side in [-1.0, 1.0]:
		for i in range(20):
			var x: float = side * 10.885
			var z := _rng.randf_range(-21, 21)
			var h := _rng.randf_range(0.3, 1.8)
			_box(self, "RisingDamp", Vector3(x, h * 0.5, z), Vector3(0.012, h, _rng.randf_range(0.03, 0.10)), "black")
	# Scattered candle stubs along the public path.
	for side in [-1.0, 1.0]:
		for z in [-12.0, -4.0, 4.0, 12.0]:
			_candle(self, Vector3(side * 2.22, 0.05, z), 0.13, false)


func collect_seal(id: String) -> void:
	if not pickups.has(id):
		return
	var seal: Node3D = pickups[id]
	if is_instance_valid(seal):
		seal.queue_free()
	pickups.erase(id)
	_seal_bases.erase(id)


func set_awakened(active: bool) -> void:
	_awake = active
	if is_instance_valid(_god_light):
		_god_light.light_color = Color("dc332b") if active else Color("c26842")
	for fissure in _fissures:
		fissure.scale.x = 2.5 if active else 1.0


func open_exit() -> void:
	if _opened:
		return
	_opened = true
	if is_instance_valid(_door_body):
		_door_body.collision_layer = 0
		_door_body.collision_mask = 0
	var tween := create_tween()
	tween.tween_property(_door_pivot, "rotation:y", deg_to_rad(103.0), 2.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_exit_light.light_color = Color("d9d3ac")
	_exit_light.light_energy = 1.8


func update_atmosphere(time: float, intensity: float) -> void:
	var dread := clampf(intensity, 0.0, 1.0)
	for i in range(_lamps.size()):
		var lamp := _lamps[i]
		var base := 0.7 if i < 3 else 1.8
		var flicker := 0.93 + sin(time * 13.1 + float(i) * 2.8) * 0.035 + sin(time * 29.3 + float(i) * 1.4) * 0.028
		if _awake and i < 3:
			flicker *= 0.70 + sin(time * 3.7 + float(i)) * 0.20
		lamp.light_energy = base * flicker * (1.0 - dread * 0.24)
	for i in range(_flames.size()):
		var pulse := sin(time * 9.0 + float(i) * 1.8)
		_flames[i].scale = Vector3(1.0 + pulse * 0.10, 1.0 + pulse * 0.19, 1.0)
	for id in pickups:
		var seal: Node3D = pickups[id]
		var base: Vector3 = _seal_bases[id]
		seal.position.y = base.y + sin(time * 1.3 + base.z) * 0.035
		seal.rotation.y = sin(time * 0.7 + base.x) * 0.24
	if is_instance_valid(idol):
		if _awake:
			idol.position = _idol_rest + Vector3(sin(time * 0.37) * 0.045, sin(time * 0.73) * 0.048, sin(time * 0.43) * 0.035)
			idol.rotation.z = sin(time * 0.62) * 0.014
		else:
			idol.position = _idol_rest
			idol.rotation.z = 0.0
	if is_instance_valid(_god_light):
		_god_light.light_energy = (2.25 if _awake else 1.35) + sin(time * 2.1) * (0.38 if _awake else 0.06)
	if _environment != null:
		_environment.fog_density = 0.016 + dread * 0.009


func _box(parent: Node3D, object_name: String, pos: Vector3, size: Vector3, material_name: String, collision: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = object_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _materials[material_name]
	parent.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.name = "Solid"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		instance.add_child(body)
	return instance


func _cylinder(parent: Node3D, object_name: String, pos: Vector3, radius: float, height: float, material_name: String, segments: int = 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.name = object_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _materials[material_name]
	parent.add_child(instance)
	return instance


func _sphere(parent: Node3D, object_name: String, pos: Vector3, size: Vector3, material_name: String, segments: int = 10, rings: int = 6) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = rings
	var instance := MeshInstance3D.new()
	instance.name = object_name
	instance.mesh = mesh
	instance.position = pos
	instance.scale = size
	instance.material_override = _materials[material_name]
	parent.add_child(instance)
	return instance


func _beam(parent: Node3D, from: Vector3, to: Vector3, thickness: float, material_name: String) -> MeshInstance3D:
	var delta := to - from
	var instance := _box(parent, "Strut", (from + to) * 0.5, Vector3(thickness, delta.length(), thickness), material_name)
	var up := delta.normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.001:
		right = up.cross(Vector3.RIGHT).normalized()
	instance.basis = Basis(right, up, right.cross(up).normalized())
	return instance


func _ring(parent: Node3D, pos: Vector3, radius: float, thickness: float, material_name: String, vertical: bool = true) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(radius - thickness, 0.01)
	mesh.outer_radius = radius + thickness
	mesh.rings = 28
	mesh.ring_segments = 5
	var instance := MeshInstance3D.new()
	instance.name = "DevotionalRing"
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _materials[material_name]
	if vertical:
		instance.rotation.x = PI * 0.5
	parent.add_child(instance)
	return instance


func _light(parent: Node3D, pos: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "PracticalLight"
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.5
	light.shadow_enabled = false
	parent.add_child(light)
	return light


func _candle(parent: Node3D, base: Vector3, height: float, with_light: bool) -> void:
	_cylinder(parent, "WaxPool", base + Vector3(0, 0.006, 0), 0.095, 0.012, "wax", 7)
	_cylinder(parent, "SpentCandle", base + Vector3(0, height * 0.5, 0), 0.056, height, "wax", 7)
	var flame := _sphere(parent, "CandleFlame", base + Vector3(0, height + 0.06, 0), Vector3(0.055, 0.13, 0.055), "flame", 5, 4)
	_flames.append(flame)
	# Store shape dimensions in the mesh, so flicker scale remains relative.
	var flame_mesh := flame.mesh as SphereMesh
	flame_mesh.radius = 0.028
	flame_mesh.height = 0.13
	flame.scale = Vector3.ONE
	if with_light:
		var light := _light(parent, base + Vector3(0, height + 0.14, 0), Color("e9ad66"), 1.05, 3.5)
		_lamps.append(light)


func _label(parent: Node3D, words: String, pos: Vector3, font_size: int, pixel_size: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.name = "Inscription"
	label.text = words
	label.position = pos
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.shaded = true
	label.double_sided = false
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Consolas", "Arial"])
	label.font = font
	parent.add_child(label)
	return label
