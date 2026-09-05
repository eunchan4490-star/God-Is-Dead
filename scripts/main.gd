extends Node3D
## A complete single-session analog horror game. No network, telemetry or assets.

const WorldScript = preload("res://scripts/world.gd")
const AudioScript = preload("res://scripts/audio_director.gd")
const HudScript = preload("res://scripts/hud.gd")
enum Mode { MENU, PLAYING, NOTE, PAUSED, DEAD, WON }
const SEAL_POSITIONS := {
	"seal_1": Vector3(-8, 1.2, 8),
	"seal_2": Vector3(8, 1.2, 0),
	"seal_3": Vector3(-8, 1.2, -10)
}
const RECORDS := {
	"seal_1": ["기록 01 / 첫 번째 기도", "1998년 10월 12일\n\n우리는 신에게 고통을 가져가 달라고 했다.\n신은 우리의 고통을 모두 삼켰다.\n\n다음 날, 신의 입에서 검은 물이 흘렀다.\n우리는 그것을 기적이라고 불렀다.\n\n[ 봉인 조각을 회수했습니다. ]\n종이 울리면 F로 불을 끄고 Ctrl로 고개를 숙이세요.\n기도가 끝날 때까지 그대로 있어야 합니다."],
	"seal_2": ["기록 02 / 응답", "1998년 10월 26일\n\n우리는 더 많은 것을 빌었다.\n누군가의 사랑. 누군가의 실패. 누군가의 죽음.\n\n신은 한 번도 거절하지 않았다.\n그렇게 신은 우리가 원하는 모습이 되었다.\n\n제단 아래에서 사람의 목소리가 들린다.\n전부 우리가 했던 기도다.\n\n[ 봉인 조각을 회수했습니다. ]"],
	"seal_3": ["기록 03 / 사망 확인서", "1998년 11월 03일 / 02:17\n\n신은 죽었다. 우리가 죽였다.\n\n시체는 사흘째 기도를 받고 있다.\n그것은 더 이상 우리를 구하려 하지 않는다.\n우리가 바랐던 것들을 돌려주려 한다.\n\n세 봉인을 제단에 놓아라.\n의식이 끝나면 들어온 문으로 돌아가라.\n뒤에서 네 이름을 불러도 돌아보지 마라.\n\n[ 마지막 봉인을 회수했습니다. ]"]
}

var mode: Mode = Mode.MENU
var world: Node3D
var audio: Node
var hud: CanvasLayer
var player: CharacterBody3D
var camera: Camera3D
var flashlight: SpotLight3D
var entity: Node3D
var entity_light: OmniLight3D
var seal_ids: Array[String] = []
var phase := "search"
var elapsed := 0.0
var visual_time := 0.0
var battery := 100.0
var stamina := 100.0
var light_on := true
var sensitivity := 0.0023
var brightness := 1.12
var volume := 0.65
var vhs_strength := 0.72
var prayer_clock := 23.0
var prayer_left := 0.0
var warning_left := 0.0
var exposure := 0.0
var ritual_progress := 0.0
var footstep_clock := 0.0
var subtitle_clock := 0.0
var subtitle_text := ""
var interact_target := ""
var bob := 0.0
var scare_amount := 0.0
var has_prayed := false
var knees_down := false
var escape_time := 0.0
var last_note := ""
var qa_mode := false
var fps_samples: Array[float] = []

func _ready() -> void:
	_register_inputs()
	world = WorldScript.new()
	add_child(world)
	world.build()
	_create_player()
	_create_entity()
	audio = AudioScript.new()
	add_child(audio)
	hud = HudScript.new()
	add_child(hud)
	hud.setup()
	hud.start_requested.connect(start_game)
	hud.resume_requested.connect(_resume)
	hud.restart_requested.connect(start_game)
	hud.quit_requested.connect(func(): get_tree().quit())
	hud.settings_changed.connect(_setting_changed)
	_load_settings()
	hud.show_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var args := OS.get_cmdline_user_args()
	qa_mode = args.has("--qa")
	if qa_mode:
		_run_qa.call_deferred()

func _register_inputs() -> void:
	var bindings := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D,
		"sprint": KEY_SHIFT, "bow": KEY_CTRL, "interact": KEY_E, "torch": KEY_F,
		"pause": KEY_ESCAPE, "journal": KEY_J, "fullscreen": KEY_F11}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)
	for entry: Array in [["forward", KEY_UP], ["back", KEY_DOWN], ["left", KEY_LEFT], ["right", KEY_RIGHT]]:
		var event := InputEventKey.new()
		event.physical_keycode = entry[1]
		InputMap.action_add_event(entry[0], event)

func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	add_child(player)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.65
	shape.shape = capsule
	shape.position.y = 0.85
	player.add_child(shape)
	player.floor_snap_length = 0.3
	camera = Camera3D.new()
	camera.name = "Camcorder"
	camera.fov = 71.0
	camera.near = 0.055
	camera.far = 85.0
	camera.position.y = 1.65
	player.add_child(camera)
	camera.current = true
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(0.82, 0.84, 0.67)
	flashlight.light_energy = 4.2
	flashlight.spot_range = 24.0
	flashlight.spot_angle = 34.0
	flashlight.spot_attenuation = 0.9
	flashlight.spot_angle_attenuation = 0.8
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.16, -0.11, 0)
	camera.add_child(flashlight)
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.49, 0.53, 0.47)
	fill.light_energy = 0.22
	fill.omni_range = 3.2
	camera.add_child(fill)
	player.position = Vector3(0, 0.1, 17)
	camera.rotation.x = 0.04

func _create_entity() -> void:
	entity = Node3D.new()
	entity.name = "TheAnswered"
	add_child(entity)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.009, 0.008, 0.008)
	black.roughness = 1
	var ivory := StandardMaterial3D.new()
	ivory.albedo_color = Color(0.65, 0.62, 0.48)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.46, 0.025, 0.01)
	red.emission_enabled = true
	red.emission = Color(0.66, 0.03, 0.008)
	red.emission_energy_multiplier = 2
	var robe := CylinderMesh.new()
	robe.top_radius = 0.21
	robe.bottom_radius = 0.66
	robe.height = 2.6
	robe.radial_segments = 7
	_entity_mesh(robe, Vector3(0, 1.3, 0), black)
	var head := SphereMesh.new()
	head.radius = 0.26
	head.height = 0.8
	head.radial_segments = 12
	head.rings = 8
	_entity_mesh(head, Vector3(0, 2.78, 0), ivory)
	var wound := BoxMesh.new()
	wound.size = Vector3(0.052, 0.47, 0.06)
	_entity_mesh(wound, Vector3(0, 2.76, 0.23), red)
	for side: float in [-1.0, 1.0]:
		var arm := CylinderMesh.new()
		arm.top_radius = 0.05
		arm.bottom_radius = 0.085
		arm.height = 2.4
		arm.radial_segments = 5
		var limb := _entity_mesh(arm, Vector3(side * 0.6, 1.8, 0), black)
		limb.rotation.z = side * 0.25
	var halo := TorusMesh.new()
	halo.inner_radius = 0.46
	halo.outer_radius = 0.49
	halo.rings = 24
	halo.ring_segments = 5
	var ring := _entity_mesh(halo, Vector3(0, 2.9, -0.1), red)
	ring.rotation.x = PI / 2
	entity_light = OmniLight3D.new()
	entity_light.light_color = Color(0.75, 0.022, 0.008)
	entity_light.light_energy = 1.3
	entity_light.omni_range = 5
	entity_light.position.y = 2.1
	entity.add_child(entity_light)
	entity.visible = false

func _entity_mesh(mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	entity.add_child(instance)
	return instance

func start_game() -> void:
	# Recreate level to reset all candles and door state across repeated games.
	remove_child(world)
	world.queue_free()
	world = WorldScript.new()
	add_child(world)
	world.build()
	seal_ids.clear()
	phase = "search"
	elapsed = 0
	battery = 100
	stamina = 100
	light_on = true
	prayer_clock = 23
	prayer_left = 0
	warning_left = 0
	exposure = 0
	ritual_progress = 0
	escape_time = 0
	has_prayed = false
	knees_down = false
	last_note = ""
	entity.visible = false
	player.position = Vector3(0, 0.1, 17)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	mode = Mode.PLAYING
	hud.show_game()
	audio.start_ambience()
	audio.set_paused(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_say("사망 확인  /  1998.11.03\n세 봉인을 찾아, 죽은 신의 기도를 멈추세요.", 7)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if mode == Mode.PLAYING:
			_pause()
		elif mode == Mode.PAUSED or mode == Mode.NOTE:
			_resume()
		return
	if mode == Mode.NOTE and event.is_action_pressed("interact"):
		_resume()
		return
	if mode == Mode.MENU and event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		start_game()
		return
	if mode != Mode.PLAYING:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * sensitivity)
		if not knees_down:
			camera.rotation.x = clampf(camera.rotation.x - event.relative.y * sensitivity, -1.4, 1.35)
	if event.is_action_pressed("torch"):
		if battery > 3 or light_on:
			light_on = not light_on
			audio.play_cue("click")
		else:
			_say("배터리가 비었습니다. 잠시 불을 끄면 회복됩니다.", 3)
	if event.is_action_pressed("interact"):
		_interact()
	if event.is_action_pressed("journal") and not last_note.is_empty():
		_open_record(last_note)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == Mode.PLAYING and not qa_mode:
		_pause()

func _pause() -> void:
	mode = Mode.PAUSED
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_pause()
	audio.set_paused(true)

func _resume() -> void:
	if mode != Mode.NOTE and mode != Mode.PAUSED:
		return
	mode = Mode.PLAYING
	hud.close_note()
	hud.show_game()
	audio.set_paused(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if mode != Mode.PLAYING:
		return
	knees_down = Input.is_action_pressed("bow")
	var axis := Input.get_vector("left", "right", "forward", "back")
	var direction := (player.transform.basis * Vector3(axis.x, 0, axis.y)).normalized()
	var sprinting := Input.is_action_pressed("sprint") and stamina > 1 and axis.length() > 0 and not knees_down
	var speed := 4.8 if sprinting else 2.7
	if knees_down:
		speed = 1.1
		camera.rotation.x = lerpf(camera.rotation.x, -1.13, minf(delta * 13, 1))
	stamina = clampf(stamina + (-19.0 if sprinting else 12.0) * delta, 0, 100)
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if not player.is_on_floor():
		player.velocity.y -= 16 * delta
	else:
		player.velocity.y = -0.3
	player.move_and_slide()
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.1
	if moving and player.is_on_floor():
		bob += delta * (12 if sprinting else 7.4)
		footstep_clock -= delta
		if footstep_clock <= 0:
			audio.footstep(sprinting)
			footstep_clock = 0.3 if sprinting else 0.48
	var eye_height := 1.04 if knees_down else 1.65
	camera.position.y = lerpf(camera.position.y, eye_height + (sin(bob) * 0.026 if moving else 0.0), minf(delta * 12, 1))
	camera.rotation.z = lerpf(camera.rotation.z, (sin(bob * 0.5) * 0.006 if moving else 0.0), minf(delta * 5, 1))

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	visual_time += delta
	if mode == Mode.MENU:
		player.rotation.y = sin(visual_time * 0.09) * 0.10
		camera.rotation.x = 0.04 + sin(visual_time * 0.11) * 0.018
	if mode != Mode.PLAYING:
		world.update_atmosphere(visual_time, 0.05)
		return
	elapsed += delta
	if qa_mode:
		fps_samples.append(float(Engine.get_frames_per_second()))
	battery = clampf(battery + (-0.9 if light_on else 4.6) * delta, 0, 100)
	if battery <= 0 and light_on:
		light_on = false
		audio.play_cue("battery")
	flashlight.visible = light_on
	flashlight.light_energy = 4.2 * brightness * (0.82 + 0.18 * minf(battery / 18, 1))
	if battery < 14 and light_on:
		flashlight.light_energy *= 0.75 + 0.25 * sin(visual_time * 47)
	if subtitle_clock > 0:
		subtitle_clock -= delta
		if subtitle_clock <= 0:
			hud.set_subtitle("")
	_update_prayer(delta)
	_update_interaction()
	if phase == "ritual" and interact_target == "altar" and Input.is_action_pressed("interact") and prayer_left <= 0 and warning_left <= 0:
		ritual_progress += delta
		hud.set_prompt("[ E 길게 ]  봉인 중  %02d%%" % int(ritual_progress / 6.0 * 100))
		if ritual_progress >= 6:
			_begin_escape()
	elif phase == "ritual" and ritual_progress > 0:
		ritual_progress = maxf(0, ritual_progress - delta * 0.35)
	if phase == "escape":
		_update_pursuit(delta)
	var tension := clampf(exposure / 2.8 + (0.45 if prayer_left > 0 else 0) + (0.55 if phase == "escape" else seal_ids.size() * 0.08), 0, 1)
	scare_amount = maxf(0, scare_amount - delta * 0.5)
	hud.set_threat(maxf(tension * 0.75, scare_amount))
	audio.set_intensity(tension)
	world.update_atmosphere(visual_time, tension)
	hud.set_status(_objective(), seal_ids.size(), battery / 100.0, stamina / 100.0, elapsed)

func _objective() -> String:
	if phase == "escape":
		return "돌아보지 마세요. 입구의 붉은 문으로 탈출하세요."
	if phase == "ritual":
		return "제단으로 돌아가 E를 길게 눌러 봉인하세요."
	if seal_ids.is_empty():
		return "세 봉인을 찾으세요 · 촛불이 켜진 벽면을 살피세요."
	return "남은 봉인을 찾으세요 · 종이 울리면 F → Ctrl."

func _update_interaction() -> void:
	interact_target = ""
	var best_distance := 2.55
	for id: String in SEAL_POSITIONS:
		if seal_ids.has(id):
			continue
		var distance: float = camera.global_position.distance_to(SEAL_POSITIONS[id])
		if distance < best_distance and _can_see(SEAL_POSITIONS[id]):
			best_distance = distance
			interact_target = id
	if camera.global_position.distance_to(Vector3(0, 1.3, -17)) < 3.0 and _can_see(Vector3(0, 1.3, -17)):
		interact_target = "altar"
	if camera.global_position.distance_to(Vector3(0, 1.5, 20.5)) < 3.0:
		interact_target = "exit"
	var prompt := ""
	if interact_target.begins_with("seal_"):
		prompt = "[ E ]  봉인과 기록 회수"
	elif interact_target == "altar":
		prompt = "[ E 길게 ]  마지막 봉인" if phase == "ritual" else "세 봉인이 필요합니다.  %d / 3" % seal_ids.size()
	elif interact_target == "exit":
		prompt = "[ E ]  탈출" if phase == "escape" else "문은 안쪽에서 봉인되어 있습니다."
	hud.set_prompt(prompt)

func _can_see(target: Vector3) -> bool:
	var direction := camera.global_position.direction_to(target)
	return (-camera.global_transform.basis.z).dot(direction) > 0.45

func _interact() -> void:
	if mode != Mode.PLAYING:
		return
	if interact_target.begins_with("seal_") and not seal_ids.has(interact_target):
		_collect(interact_target)
	elif interact_target == "exit" and phase == "escape":
		_finish(true)
	elif interact_target == "exit":
		_say("문 너머에서도 기도가 들린다. 먼저 제단을 봉인해야 한다.", 4)
	elif interact_target == "altar" and phase == "search":
		_say("빈 자리가 세 개다. 누군가 신을 다시 깨우려 했다.", 4)

func _collect(id: String) -> void:
	seal_ids.append(id)
	world.collect_seal(id)
	audio.play_cue("pickup")
	scare_amount = 0.30
	if seal_ids.size() == 3:
		phase = "ritual"
	prayer_clock = minf(prayer_clock, 11.0 if seal_ids.size() == 1 else 15.0)
	last_note = id
	_open_record(id)

func _open_record(id: String) -> void:
	mode = Mode.NOTE
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	audio.set_paused(true)
	hud.show_note(RECORDS[id][0], RECORDS[id][1])

func _update_prayer(delta: float) -> void:
	if phase == "escape" or seal_ids.is_empty():
		return
	if warning_left > 0:
		warning_left -= delta
		if warning_left <= 0:
			prayer_left = 6.2
			exposure = 0
			entity.visible = true
			var forward := -player.global_transform.basis.z
			entity.position = player.position + forward * 7
			entity.position.x = clampf(entity.position.x, -9, 9)
			entity.position.z = clampf(entity.position.z, -19, 19)
			entity.look_at(Vector3(player.position.x, entity.position.y, player.position.z), Vector3.UP, true)
			audio.play_cue("whisper")
			_say("불을 끄세요. 고개를 숙이세요.\n[ F ] 손전등  /  [ Ctrl 길게 ] 고개 숙이기", 7)
	elif prayer_left > 0:
		prayer_left -= delta
		var obeying := not light_on and camera.rotation.x < -0.70
		if obeying:
			has_prayed = true
			exposure = maxf(0, exposure - delta * 1.8)
		else:
			exposure += delta
		entity.visible = sin(visual_time * 17) > -0.35
		if exposure > 2.8:
			_finish(false)
		if prayer_left <= 0:
			entity.visible = false
			exposure = 0
			prayer_clock = 24 - seal_ids.size() * 2
			_say("기도가 멎었다. 이제 움직여도 된다.", 3)
	else:
		prayer_clock -= delta
		if prayer_clock <= 0:
			warning_left = 3.8
			audio.play_cue("bell")
			_say("종이 울린다. 그것이 기도를 시작한다.\n불을 끄고 고개를 숙일 준비를 하세요.", 4)

func _begin_escape() -> void:
	phase = "escape"
	prayer_left = 0
	warning_left = 0
	exposure = 0
	escape_time = 0
	world.set_awakened(true)
	world.open_exit()
	entity.position = Vector3(0, 0.1, -21)
	entity.visible = true
	light_on = true
	battery = maxf(battery, 50)
	stamina = 100
	scare_amount = 0.72
	audio.play_cue("ritual")
	_say("신은 죽었다. 우리가 죽였다.\n그런데 왜 아직도 응답하는가.\n\n입구의 붉은 문으로 뛰세요. [ Shift ]", 7)

func _update_pursuit(delta: float) -> void:
	escape_time += delta
	if escape_time < 2.5:
		return
	var target := Vector3(player.position.x, 0.1, player.position.z)
	var distance := entity.position.distance_to(target)
	var forward_dot := (-camera.global_transform.basis.z).dot(camera.global_position.direction_to(entity.position + Vector3(0, 2, 0)))
	var speed := 2.1 if forward_dot < 0.45 else 3.3
	entity.position = entity.position.move_toward(target, delta * speed)
	entity.position.y = 0.1 + sin(visual_time * 2.7) * 0.08
	if distance > 0.05:
		entity.look_at(Vector3(player.position.x, entity.position.y, player.position.z), Vector3.UP, true)
	exposure = clampf((7.5 - distance) * 0.35, 0, 2.6)
	if distance < 1.15:
		_finish(false)

func _finish(won: bool) -> void:
	if mode != Mode.PLAYING:
		return
	mode = Mode.WON if won else Mode.DEAD
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_prompt("")
	hud.set_subtitle("")
	hud.set_threat(0.12 if won else 1.0)
	audio.play_cue("win" if won else "scare")
	audio.set_paused(true)
	if not won:
		entity.visible = true
		entity.position = player.position - player.global_transform.basis.z * 1.2
		entity.look_at(Vector3(player.position.x, entity.position.y, player.position.z), Vector3.UP, true)
		hud.show_ending(false, elapsed, has_prayed)
	else:
		hud.show_ending(true, elapsed, has_prayed)

func _say(text: String, seconds: float) -> void:
	subtitle_text = text
	subtitle_clock = seconds
	hud.set_subtitle(text)

func _setting_changed(key: String, value: float) -> void:
	match key:
		"volume":
			volume = value
			audio.set_volume(value)
		"sensitivity": sensitivity = value * 0.003 + 0.0005
		"brightness":
			brightness = value
			hud.set_brightness(value)
		"vhs":
			vhs_strength = value
			hud.set_vhs_strength(value)
	_save_settings()

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "volume", volume)
	config.set_value("settings", "sensitivity", sensitivity)
	config.set_value("settings", "brightness", brightness)
	config.set_value("settings", "vhs", vhs_strength)
	config.save("user://settings.cfg")

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		volume = clampf(float(config.get_value("settings", "volume", volume)), 0, 1)
		sensitivity = clampf(float(config.get_value("settings", "sensitivity", sensitivity)), 0.0005, 0.006)
		brightness = clampf(float(config.get_value("settings", "brightness", brightness)), 0.65, 1.8)
		vhs_strength = clampf(float(config.get_value("settings", "vhs", vhs_strength)), 0, 1)
	audio.set_volume(volume)
	hud.set_brightness(brightness)
	hud.set_vhs_strength(vhs_strength)
	hud.sync_settings(volume, (sensitivity - 0.0005) / 0.003, brightness, vhs_strength)

func _run_qa() -> void:
	# Exercised only by an explicit command-line flag; regular runs expose no cheats.
	await get_tree().create_timer(1.2).timeout
	await _capture("01_title")
	start_game()
	await get_tree().create_timer(0.6).timeout
	await _capture("02_nave")
	for id: String in SEAL_POSITIONS:
		player.position = SEAL_POSITIONS[id] + Vector3(0, -1.1, 1.5)
		player.rotation.y = 0
		camera.rotation.x = -0.2
		await get_tree().create_timer(0.3).timeout
		_update_interaction()
		assert(interact_target == id, "Seal interaction unreachable: " + id)
		_interact()
		assert(mode == Mode.NOTE)
		await _capture("03_" + id)
		_resume()
	assert(seal_ids.size() == 3 and phase == "ritual")
	# Survive a complete real prayer by obeying the rule.
	player.position = Vector3(0, 0.1, 6)
	prayer_clock = 0.01
	await get_tree().create_timer(4.0).timeout
	light_on = false
	camera.rotation.x = -1.1
	await get_tree().create_timer(6.4).timeout
	assert(mode == Mode.PLAYING and has_prayed, "Prayer survival failed")
	light_on = true
	camera.rotation.x = 0.08
	player.position = Vector3(0, 0.1, -14.7)
	await get_tree().create_timer(0.4).timeout
	await _capture("04_altar")
	_update_interaction()
	assert(interact_target == "altar")
	Input.action_press("interact")
	await get_tree().create_timer(6.3).timeout
	Input.action_release("interact")
	assert(phase == "escape", "Ritual did not complete")
	player.rotation.y = PI
	await _capture("05_escape")
	player.position = Vector3(0, 0.1, 19)
	await get_tree().create_timer(0.15).timeout
	_update_interaction()
	_interact()
	assert(mode == Mode.WON, "Exit did not win")
	await _capture("06_ending")
	start_game()
	assert(seal_ids.is_empty() and phase == "search" and battery > 99)
	_collect("seal_1")
	_resume()
	prayer_clock = 0.01
	light_on = true
	camera.rotation.x = 0
	await get_tree().create_timer(7.5).timeout
	assert(mode == Mode.DEAD, "Prayer failure did not kill")
	await _capture("07_lost")
	print("QA PASS: 3 pickups, records, prayer survival/death, ritual, escape, win, restart.")
	get_tree().quit(0)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa"))
	get_viewport().get_texture().get_image().save_png("res://qa/" + label + ".png")
