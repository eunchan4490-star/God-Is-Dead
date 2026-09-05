extends SceneTree
## Integration test: traverses the chapel using the game's actual input and
## CharacterBody3D.move_and_slide(). No objective or escape teleportation.

var game
var failures: Array[String] = []
var checks: int = 0
var walked_metres: float = 0.0
var began_msec: int = 0
var completed: bool = false


func _initialize() -> void:
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 120
	Engine.max_physics_steps_per_frame = 16
	Engine.max_fps = 120
	began_msec = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if not completed and Time.get_ticks_msec() - began_msec > 38000:
		_fail("Integration test exceeded its 38 second wall-clock bound")
		completed = true
		_release_inputs()
		quit(1)
	return false


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		_fail(message)
	return condition


func _fail(message: String) -> void:
	failures.append(message)
	push_error("GAMEPLAY_CHECK_FAILED: " + message)


func _release_inputs() -> void:
	for action in ["forward", "back", "left", "right", "sprint", "bow", "interact"]:
		if InputMap.has_action(action):
			Input.action_release(action)


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _run() -> void:
	var script = load("res://scripts/main.gd")
	if not _check(script != null, "Main script must load"):
		await _finish()
		return
	game = script.new()
	root.add_child(game)
	game.qa_mode = true # Suppress desktop focus notifications only.
	game.audio.set_volume(0.0)
	_check(game.mode == game.Mode.MENU, "Game opens on the title screen")
	game.start_game()
	await _frames(16)
	_check(game.mode == game.Mode.PLAYING, "Start enters gameplay")
	_check(game.player.is_on_floor(), "Player settles onto the chapel floor")
	_check(game.player.position.y > -0.2, "Floor collision prevents falling")
	await _test_pause()

	# Use the centre aisle, then the wall-side aisles. Every step goes through
	# main._physics_process, preserving the capsule and all world collisions.
	var routes: Array = [
		[Vector3(0, 0, 14), Vector3(-8.9, 0, 14), Vector3(-8.9, 0, 9.5)],
		[Vector3(-8.9, 0, 14), Vector3(0, 0, 14), Vector3(8.9, 0, 14), Vector3(8.9, 0, 1.5)],
		[Vector3(8.9, 0, -12.5), Vector3(0, 0, -12.5), Vector3(-8.9, 0, -12.5), Vector3(-8.9, 0, -11.5)]
	]
	for seal_index in range(3):
		for point: Vector3 in routes[seal_index]:
			if not await _walk(point):
				await _finish()
				return
		var id: String = "seal_%d" % (seal_index + 1)
		_face(game.SEAL_POSITIONS[id])
		game._update_interaction()
		if not _check(game.interact_target == id, "Walking route reaches visible " + id):
			await _finish()
			return
		game._interact()
		_check(game.mode == game.Mode.NOTE, id + " opens its record")
		_check(game.seal_ids.size() == seal_index + 1, id + " is counted exactly once")
		var count_before: int = game.seal_ids.size()
		game._interact()
		_check(game.seal_ids.size() == count_before, "Record modal blocks duplicate interaction")
		await _test_note_pause()
		game._resume()
		game._interact()
		_check(game.seal_ids.size() == count_before, "Stale interaction target cannot duplicate a seal")
		game._update_interaction()
		_check(game.interact_target != id, "Collected seal is removed from targets")
		print("GAMEPLAY_ROUTE_OK ", id, " at ", game.player.position)

	_check(game.phase == "ritual", "Three seals unlock the ritual")
	# Guarantee a full warning/prayer cycle is tested even on a very fast host.
	game.prayer_clock = 0.001
	while game.warning_left <= 0 and game.prayer_left <= 0 and game.mode == game.Mode.PLAYING:
		await physics_frame
	await _obey_prayer()
	_check(game.has_prayed and game.mode == game.Mode.PLAYING, "Obeying survives a complete prayer")
	for point: Vector3 in [Vector3(-8.9, 0, -12.5), Vector3(0, 0, -12.5), Vector3(0, 0, -14.7)]:
		if not await _walk(point):
			await _finish()
			return
	_face(Vector3(0, 1.3, -17))
	game._update_interaction()
	if not _check(game.interact_target == "altar", "Altar is reachable through collisions"):
		await _finish()
		return
	game.prayer_clock = 30.0
	Input.action_press("interact")
	var ritual_started: int = Time.get_ticks_msec()
	while game.phase == "ritual" and game.mode == game.Mode.PLAYING and Time.get_ticks_msec() - ritual_started < 5000:
		await physics_frame
	Input.action_release("interact")
	if not _check(game.phase == "escape", "Holding E completes the real ritual"):
		await _finish()
		return
	if not await _walk(Vector3(0, 0, 19.0), true):
		await _finish()
		return
	_face(Vector3(0, 1.5, 20.5))
	game._update_interaction()
	_check(game.interact_target == "exit", "Open exit is reachable by walking the aisle")
	game._interact()
	_check(game.mode == game.Mode.WON, "Exit interaction wins after a physical escape")
	_check(walked_metres > 100.0, "Integration traversed a substantial distance without teleporting")
	await _test_restart_and_failure()
	await _finish()


func _face(target: Vector3) -> void:
	var flat: Vector3 = target - game.player.global_position
	game.player.rotation.y = atan2(-flat.x, -flat.z)
	game.camera.look_at(target, Vector3.UP)


func _walk(target: Vector3, sprinting: bool = false) -> bool:
	var started: int = Time.get_ticks_msec()
	var last_progress: Vector3 = game.player.position
	var progress_at: int = started
	while true:
		if not _check(game.mode == game.Mode.PLAYING, "Player remains alive while walking to " + str(target)):
			_release_inputs()
			return false
		if game.warning_left > 0 or game.prayer_left > 0:
			_release_inputs()
			await _obey_prayer()
			started = Time.get_ticks_msec()
			progress_at = started
		var offset: Vector3 = target - game.player.position
		offset.y = 0.0
		if offset.length() < 0.20:
			break
		game.player.rotation.y = atan2(-offset.x, -offset.z)
		game.camera.rotation.x = 0.0
		Input.action_press("forward")
		if sprinting:
			Input.action_press("sprint")
		var before: Vector3 = game.player.position
		await physics_frame
		walked_metres += game.player.position.distance_to(before)
		var now: int = Time.get_ticks_msec()
		if game.player.position.distance_to(last_progress) > 0.20:
			last_progress = game.player.position
			progress_at = now
		if now - progress_at > 1800 or now - started > 8000:
			_fail("Collision route blocked: target=%s actual=%s" % [target, game.player.position])
			_release_inputs()
			return false
	_release_inputs()
	await physics_frame
	return true


func _obey_prayer() -> void:
	_release_inputs()
	game.light_on = false
	Input.action_press("bow")
	var started: int = Time.get_ticks_msec()
	while (game.warning_left > 0 or game.prayer_left > 0) and game.mode == game.Mode.PLAYING:
		await physics_frame
		if Time.get_ticks_msec() - started > 6000:
			_fail("Prayer cycle did not finish within its bounded duration")
			break
	Input.action_release("bow")
	game.camera.rotation.x = 0.0
	game.light_on = true


func _test_pause() -> void:
	game.warning_left = 2.0
	game.prayer_left = 3.0
	game.battery = 73.0
	game._pause()
	var before: Array = [game.battery, game.stamina, game.elapsed, game.warning_left, game.prayer_left, game.player.position]
	Input.action_press("forward")
	await _frames(20)
	_release_inputs()
	_check(before == [game.battery, game.stamina, game.elapsed, game.warning_left, game.prayer_left, game.player.position], "Pause freezes movement, battery, stamina, time, warning and prayer")
	game._resume()
	game.warning_left = 0.0
	game.prayer_left = 0.0
	game.battery = 100.0


func _test_note_pause() -> void:
	var before: Array = [game.battery, game.elapsed, game.prayer_clock, game.warning_left, game.prayer_left, game.player.position]
	await _frames(8)
	_check(before == [game.battery, game.elapsed, game.prayer_clock, game.warning_left, game.prayer_left, game.player.position], "Reading a record freezes gameplay and threats")


func _test_restart_and_failure() -> void:
	game.start_game()
	_check(game.seal_ids.is_empty() and game.phase == "search", "Restart clears inventory and phase")
	_check(game.battery == 100 and game.stamina == 100, "Restart restores battery and stamina")
	_check(game.prayer_left == 0 and game.warning_left == 0 and game.exposure == 0, "Restart clears all threat timers")
	_check(not game.entity.visible and game.ritual_progress == 0 and not game.has_prayed, "Restart clears entity, ritual and prayer flags")
	_check(game.player.position.distance_to(Vector3(0, 0.1, 17)) < 0.01, "Restart returns the player to the entrance")
	# A controlled failure tests the exposure rule without a second full route.
	game.seal_ids.append("seal_1")
	game.prayer_left = 6.2
	game.light_on = true
	game.camera.rotation.x = 0.0
	var began: int = Time.get_ticks_msec()
	while game.mode == game.Mode.PLAYING and Time.get_ticks_msec() - began < 3500:
		await physics_frame
	_check(game.mode == game.Mode.DEAD, "Ignoring a prayer causes death")
	game.start_game()
	_check(game.mode == game.Mode.PLAYING and game.seal_ids.is_empty() and not game.entity.visible, "Restart also works after death")


func _finish() -> void:
	completed = true
	_release_inputs()
	if is_instance_valid(game):
		game.queue_free()
	await create_timer(1.2).timeout # 0.3 real seconds: release audio mixer streams.
	Engine.time_scale = 1.0
	print("GAMEPLAY_TEST_RESULT checks=", checks, " failures=", failures.size(), " walked_metres=", snappedf(walked_metres, 0.1), " wall_seconds=", float(Time.get_ticks_msec() - began_msec) / 1000.0)
	quit(0 if failures.is_empty() else 1)
