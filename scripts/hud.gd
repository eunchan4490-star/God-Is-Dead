class_name HorrorHUD
extends CanvasLayer
## The camera's tape treatment is drawn before the archive interface, leaving text crisp.

signal start_requested
signal resume_requested
signal restart_requested
signal quit_requested
signal settings_changed(key: String, value: float)

const IVORY := Color("e2dbc9")
const MUTED := Color("8f9185")
const BLOOD := Color("8b342d")
const INK := Color("080b0a")

var _built := false
var _root: Control
var _world_filter: ColorRect
var _filter_material: ShaderMaterial
var _game: Control
var _menu: Control
var _ending: Control
var _note: Control
var _objective: Label
var _seal_labels: Array[Label] = []
var _battery: ProgressBar
var _stamina: ProgressBar
var _battery_text: Label
var _timecode: Label
var _rec_dot: Label
var _prompt: Label
var _subtitle: Label
var _subtitle_backing: PanelContainer
var _menu_kicker: Label
var _menu_primary: Button
var _menu_restart: Button
var _menu_rule: Label
var _menu_controls: Label
var _menu_headsup: Label
var _ending_kicker: Label
var _ending_title: Label
var _ending_body: Label
var _ending_metadata: Label
var _note_title: Label
var _note_body: Label
var _note_index: Label
var _pause_mode := false
var _seconds := 0.0
var _clock := 0.0
var _note_serial := 0
var _sliders: Dictionary = {}
var _setting_labels: Dictionary = {}
var _reduced: CheckBox


func setup() -> void:
	if _built:
		return
	_built = true
	layer = 100
	_root = Control.new()
	_root.name = "ArchiveInterface"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "sans-serif"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	_root.theme = theme
	_filter_material = ShaderMaterial.new()
	_filter_material.shader = load("res://shaders/vhs.gdshader") as Shader
	_world_filter = ColorRect.new()
	_world_filter.name = "TapeSignal"
	_world_filter.material = _filter_material
	_world_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_world_filter)
	_build_game()
	_build_menu()
	_build_ending()
	_build_note()
	show_menu()


func _process(delta: float) -> void:
	_clock += delta
	if not _built:
		return
	_rec_dot.modulate.a = 1.0 if fmod(_clock, 1.8) < 1.25 else 0.28
	if _game.visible:
		var frames := int(fmod(_seconds, 1.0) * 25.0)
		_timecode.text = "%02d:%02d:%02d:%02d" % [int(_seconds) / 3600, (int(_seconds) / 60) % 60, int(_seconds) % 60, frames]


func _control(parent: Node, node_name: String = "") -> Control:
	var control := Control.new()
	control.name = node_name
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return control


func _label(text_value: String, font_size: int = 16, color: Color = IVORY, serif: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if serif:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Batang", "Georgia", "serif"])
		label.add_theme_font_override("font", font)
	return label


func _rect(parent: Node, position_value: Vector2, size_value: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = position_value
	rect.size = size_value
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _style(background: Color, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


func _button(text_value: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 43)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", IVORY if primary else Color("b5b6a9"))
	button.add_theme_color_override("font_hover_color", Color("fff9e8"))
	button.add_theme_color_override("font_focus_color", Color("fff9e8"))
	button.add_theme_color_override("font_pressed_color", IVORY)
	var normal := _style(Color(0.12, 0.14, 0.12, 0.62) if primary else Color(0.025, 0.034, 0.03, 0.4), Color("606454") if primary else Color("2e352e"), 1)
	if primary:
		normal.border_width_left = 3
		normal.border_color = Color("878c72")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _style(Color("242c24"), Color("969e83"), 1))
	button.add_theme_stylebox_override("pressed", _style(Color("181b15"), IVORY, 1))
	button.add_theme_stylebox_override("focus", _style(Color(0.0, 0.0, 0.0, 0.0), Color("bbb99f"), 1))
	return button


func _line(parent: Node, color: Color = Color("394137")) -> HSeparator:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = color
	style.thickness = 1
	line.add_theme_stylebox_override("separator", style)
	line.custom_minimum_size.y = 10
	parent.add_child(line)
	return line


func _spacer(parent: Node, height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)
	return spacer


func _anchor(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.anchor_left = left
	node.anchor_top = top
	node.anchor_right = right
	node.anchor_bottom = bottom


func _build_game() -> void:
	_game = _control(_root, "CameraOverlay")
	# Broken corner marks suggest a viewfinder without boxing the entire scene in.
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var mark := Control.new()
		_game.add_child(mark)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_anchor(mark, corner.x, corner.y, corner.x, corner.y)
		mark.position = Vector2(27.0 if corner.x == 0.0 else -27.0, 25.0 if corner.y == 0.0 else -25.0)
		_rect(mark, Vector2(0 if corner.x == 0.0 else -22, 0), Vector2(22, 1), Color(0.75, 0.78, 0.67, 0.45))
		_rect(mark, Vector2(0, 0 if corner.y == 0.0 else -17), Vector2(1, 17), Color(0.75, 0.78, 0.67, 0.45))
	var top := HBoxContainer.new()
	_game.add_child(top)
	_anchor(top, 0.04, 0.045, 0.96, 0.09)
	top.add_theme_constant_override("separation", 9)
	_rec_dot = _label("●", 13, Color("aa463e"))
	top.add_child(_rec_dot)
	top.add_child(_label("REC", 15, IVORY))
	var archive := _label("  /  ARCHIVE 003", 12, MUTED)
	archive.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(archive)
	top.add_child(_label("1998.11.03", 13, Color("b5b7a5")))
	top.add_child(_label("    SP  ▸    ", 12, MUTED))
	_timecode = _label("00:00:00:00", 15, IVORY)
	top.add_child(_timecode)
	var objective_box := VBoxContainer.new()
	_game.add_child(objective_box)
	_anchor(objective_box, 0.045, 0.13, 0.50, 0.3)
	objective_box.add_theme_constant_override("separation", 7)
	objective_box.add_child(_label("기록자의 지시", 11, MUTED))
	_objective = _label("성당 안으로 들어가세요", 17, IVORY)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_objective.add_theme_constant_override("shadow_offset_x", 1)
	_objective.add_theme_constant_override("shadow_offset_y", 2)
	objective_box.add_child(_objective)
	var seals := HBoxContainer.new()
	seals.add_theme_constant_override("separation", 12)
	objective_box.add_child(seals)
	seals.add_child(_label("봉인", 11, MUTED))
	for i in range(3):
		var seal := _label("◇", 16, Color("777f6d"))
		seals.add_child(seal)
		_seal_labels.append(seal)
	var reticle := Control.new()
	_game.add_child(reticle)
	_anchor(reticle, 0.5, 0.5, 0.5, 0.5)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect(reticle, Vector2(-1, -1), Vector2(2, 2), Color(0.95, 0.94, 0.84, 0.78))
	_rect(reticle, Vector2(-7, 0), Vector2(3, 1), Color(0.9, 0.9, 0.8, 0.3))
	_rect(reticle, Vector2(5, 0), Vector2(3, 1), Color(0.9, 0.9, 0.8, 0.3))
	_prompt = _label("", 18, IVORY)
	_game.add_child(_prompt)
	_anchor(_prompt, 0.20, 0.705, 0.80, 0.76)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	_prompt.add_theme_constant_override("shadow_offset_y", 2)
	_subtitle_backing = PanelContainer.new()
	_game.add_child(_subtitle_backing)
	_anchor(_subtitle_backing, 0.16, 0.805, 0.84, 0.90)
	_subtitle_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_backing.add_theme_stylebox_override("panel", _style(Color(0.015, 0.02, 0.017, 0.65)))
	_subtitle = _label("", 19, Color("dfdccb"))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_backing.add_child(_subtitle)
	_subtitle_backing.hide()
	var battery_box := VBoxContainer.new()
	_game.add_child(battery_box)
	_anchor(battery_box, 0.045, 0.90, 0.205, 0.96)
	battery_box.add_theme_constant_override("separation", 6)
	_battery_text = _label("LIGHT  /  100%", 11, MUTED)
	battery_box.add_child(_battery_text)
	_battery = _make_meter(battery_box, Color("9da487"))
	var stamina_box := VBoxContainer.new()
	_game.add_child(stamina_box)
	_anchor(stamina_box, 0.795, 0.90, 0.955, 0.96)
	stamina_box.add_theme_constant_override("separation", 6)
	var breath := _label("BREATH  /  숨", 11, MUTED)
	breath.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamina_box.add_child(breath)
	_stamina = _make_meter(stamina_box, Color("8a9582"))
	var hint := _label("F  손전등    ·    E  조사    ·    CTRL  숙이기    ·    J  기록", 11, Color("777f70"))
	_game.add_child(hint)
	_anchor(hint, 0.24, 0.94, 0.76, 0.975)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _make_meter(parent: Node, color: Color) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.custom_minimum_size.y = 3
	meter.max_value = 1.0
	meter.value = 1.0
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_theme_stylebox_override("background", _style(Color("252d25")))
	meter.add_theme_stylebox_override("fill", _style(color))
	# Meters remain hairlines; the panel helper's content padding is not needed here.
	for style_name in ["background", "fill"]:
		var style := meter.get_theme_stylebox(style_name) as StyleBoxFlat
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		style.content_margin_left = 0
		style.content_margin_right = 0
	parent.add_child(meter)
	return meter


func _shade(parent: Node, opaque: bool = false) -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.63, 1.0])
	gradient.colors = PackedColorArray([Color(0.02, 0.03, 0.024, 0.98), Color(0.02, 0.03, 0.024, 0.94), Color(0.02, 0.03, 0.024, 0.52), Color(0.02, 0.03, 0.024, 0.15 if not opaque else 0.85)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 512
	texture.height = 2
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(1, 0)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var archive_rail := ColorRect.new()
	archive_rail.color = Color(0.57, 0.6, 0.48, 0.20)
	archive_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(archive_rail)
	_anchor(archive_rail, 0.027, 0.04, 0.027, 0.96)
	archive_rail.offset_right = 1


func _build_menu() -> void:
	_menu = _control(_root, "ArchiveMenu")
	_shade(_menu)
	var content := VBoxContainer.new()
	_menu.add_child(content)
	_anchor(content, 0.065, 0.055, 0.47, 0.955)
	content.add_theme_constant_override("separation", 4)
	_menu_kicker = _label("기밀 해제 기록  /  NO. 003", 12, Color("9ca38c"))
	content.add_child(_menu_kicker)
	_spacer(content, 8)
	var title := _label("신은 죽었다.", 54, IVORY, true)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.4))
	title.add_theme_constant_override("shadow_offset_y", 3)
	content.add_child(title)
	content.add_child(_label("우리가 죽였다.", 25, Color("bcbea7"), true))
	content.add_child(_label("GOD IS DEAD. WE KILLED HIM.", 11, Color("788773")))
	_spacer(content, 7)
	_line(content)
	_menu_rule = _label("세 봉인을 회수하고 제단에서 E를 길게 누르십시오.\n종이 울리면 불을 끄고 고개를 숙이세요.", 14, Color("b9bfa8"))
	_menu_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_rule.add_theme_constant_override("line_spacing", 6)
	content.add_child(_menu_rule)
	_spacer(content, 3)
	_menu_primary = _button("기록 재생                                      →", true)
	_menu_primary.pressed.connect(_on_primary_pressed)
	content.add_child(_menu_primary)
	_menu_restart = _button("처음부터 재생")
	_menu_restart.pressed.connect(func() -> void: restart_requested.emit())
	content.add_child(_menu_restart)
	_menu_restart.hide()
	var exit_button := _button("종료")
	exit_button.pressed.connect(func() -> void: quit_requested.emit())
	content.add_child(exit_button)
	_spacer(content, 4)
	var settings_title := _label("재생 장치 설정", 11, Color("87927e"))
	content.add_child(settings_title)
	_build_slider(content, "음량", "volume", 0.0, 1.0, 0.65)
	_build_slider(content, "시점 감도", "sensitivity", 0.0, 1.0, 0.60)
	_build_slider(content, "화면 밝기", "brightness", 0.65, 1.8, 1.12)
	var reduced := CheckBox.new()
	_reduced = reduced
	reduced.text = "화면 노이즈 줄이기"
	reduced.add_theme_font_size_override("font_size", 12)
	reduced.add_theme_color_override("font_color", Color("a7af97"))
	reduced.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	reduced.toggled.connect(func(enabled: bool) -> void:
		var amount := 0.15 if enabled else 0.72
		set_vhs_strength(amount)
		settings_changed.emit("vhs", amount)
	)
	content.add_child(reduced)
	var breathing_space := Control.new()
	breathing_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(breathing_space)
	_menu_controls = _label("WASD 이동 · 마우스 시점 · SHIFT 달리기 · F 손전등\nE 조사 / 길게 눌러 의식 · CTRL 숙이기 · J 기록\nESC 일시정지 · F11 전체 화면", 11, Color("8c9781"))
	_menu_controls.add_theme_constant_override("line_spacing", 3)
	content.add_child(_menu_controls)
	_menu_headsup = _label("헤드폰 권장 · 어두운 장면과 화면 흔들림 포함", 10, Color("64705e"))
	content.add_child(_menu_headsup)
	var tape_mark := VBoxContainer.new()
	_menu.add_child(tape_mark)
	_anchor(tape_mark, 0.745, 0.84, 0.945, 0.95)
	tape_mark.add_theme_constant_override("separation", 5)
	var top_text := _label("실종자 회수 영상", 12, Color("c0c4ae"))
	top_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tape_mark.add_child(top_text)
	var tape_date := _label("03 NOV 1998  /  02:17 AM", 11, Color("89977f"))
	tape_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tape_mark.add_child(tape_date)
	var evidence := _label("증거물 훼손 및 복제 금지", 10, Color("67765e"))
	evidence.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tape_mark.add_child(evidence)
	var version := _label("DEO MORTUO  /  아날로그 공포 기록", 10, Color("77866b"))
	_menu.add_child(version)
	_anchor(version, 0.65, 0.045, 0.945, 0.075)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _build_slider(parent: Node, label_text: String, key: String, minimum: float, maximum: float, initial: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size.y = 21
	parent.add_child(row)
	var label := _label(label_text, 12, Color("a2ab95"))
	label.custom_minimum_size.x = 76
	row.add_child(label)
	var slider := HSlider.new()
	_sliders[key] = slider
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.01
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 14
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var track := StyleBoxFlat.new()
	track.bg_color = Color("30392d")
	track.content_margin_top = 1
	track.content_margin_bottom = 1
	slider.add_theme_stylebox_override("slider", track)
	var filled := StyleBoxFlat.new()
	filled.bg_color = Color("929d7f")
	filled.content_margin_top = 1
	filled.content_margin_bottom = 1
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	var handle := GradientTexture2D.new()
	handle.width = 6
	handle.height = 10
	var handle_gradient := Gradient.new()
	handle_gradient.colors = PackedColorArray([Color("bac0a6"), Color("bac0a6")])
	handle.gradient = handle_gradient
	slider.add_theme_icon_override("grabber", handle)
	slider.add_theme_icon_override("grabber_highlight", handle)
	row.add_child(slider)
	var value_label := _label("%d%%" % int(initial * 100.0), 11, Color("78856b"))
	_setting_labels[key] = value_label
	value_label.custom_minimum_size.x = 40
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % int(value * 100.0)
		if key == "brightness":
			set_brightness(value)
		settings_changed.emit(key, value)
	)


func _build_ending() -> void:
	_ending = _control(_root, "TapeEnd")
	_shade(_ending, true)
	var content := VBoxContainer.new()
	_ending.add_child(content)
	_anchor(content, 0.08, 0.17, 0.61, 0.86)
	content.add_theme_constant_override("separation", 15)
	_ending_kicker = _label("END OF TAPE  /  기록 종료", 12, Color("919c83"))
	content.add_child(_ending_kicker)
	_spacer(content, 14)
	_ending_title = _label("신은 죽었다.\n우리가 죽였다.", 48, IVORY, true)
	_ending_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_ending_title)
	_line(content)
	_ending_body = _label("", 17, Color("a9b49a"))
	_ending_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_body.add_theme_constant_override("line_spacing", 7)
	content.add_child(_ending_body)
	_ending_metadata = _label("", 12, Color("76846a"))
	content.add_child(_ending_metadata)
	_spacer(content, 15)
	var restart := _button("기록 다시 재생                                →", true)
	restart.pressed.connect(func() -> void: restart_requested.emit())
	content.add_child(restart)
	var quit := _button("종료")
	quit.pressed.connect(func() -> void: quit_requested.emit())
	content.add_child(quit)
	_ending.hide()


func _build_note() -> void:
	_note = _control(_root, "EvidenceReading")
	var darkness := ColorRect.new()
	darkness.color = Color(0.0, 0.007, 0.003, 0.78)
	darkness.mouse_filter = Control.MOUSE_FILTER_STOP
	_note.add_child(darkness)
	darkness.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var paper := PanelContainer.new()
	_note.add_child(paper)
	_anchor(paper, 0.22, 0.12, 0.78, 0.88)
	var paper_style := _style(Color("10160f"), Color("4c5941"), 1)
	paper_style.content_margin_left = 38
	paper_style.content_margin_right = 38
	paper_style.content_margin_top = 29
	paper_style.content_margin_bottom = 27
	paper.add_theme_stylebox_override("panel", paper_style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	paper.add_child(content)
	_note_index = _label("회수 문서  /  EVIDENCE 01", 11, Color("899477"))
	content.add_child(_note_index)
	_note_title = _label("기록", 30, IVORY, true)
	_note_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_note_title)
	_line(content)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_note_body = _label("", 19, Color("bcc3ac"), true)
	_note_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_body.add_theme_constant_override("line_spacing", 9)
	scroll.add_child(_note_body)
	var close := _button("문서를 내려놓는다                         [ E / ESC ]", true)
	close.pressed.connect(func() -> void:
		close_note()
		resume_requested.emit()
	)
	content.add_child(close)
	_note.hide()


func _on_primary_pressed() -> void:
	if _pause_mode:
		resume_requested.emit()
	else:
		start_requested.emit()


func show_menu() -> void:
	if not _built:
		setup()
		return
	_pause_mode = false
	_game.hide()
	_ending.hide()
	_note.hide()
	_menu.show()
	_menu_kicker.text = "기밀 해제 기록  /  NO. 003"
	_menu_primary.text = "기록 재생                                      →"
	_menu_restart.hide()
	_menu_rule.text = "세 봉인을 회수하고 제단에서 E를 길게 누르십시오.\n종이 울리면 불을 끄고 고개를 숙이세요."
	_menu_controls.show()
	_menu_headsup.show()
	_menu_primary.grab_focus()


func show_pause() -> void:
	_pause_mode = true
	_game.hide()
	_ending.hide()
	_note.hide()
	_menu.show()
	_menu_kicker.text = "Ⅱ  PLAYBACK PAUSED  /  일시정지"
	_menu_primary.text = "기록 이어보기                                  →"
	_menu_restart.show()
	_menu_rule.text = "기록이 멈췄습니다. 이 화면에서는 의식도 멈춥니다."
	_menu_controls.hide()
	_menu_headsup.hide()
	_menu_primary.grab_focus()


func show_game() -> void:
	_game.show()
	_menu.hide()
	_ending.hide()
	_note.hide()
	var focus := _root.get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()


func show_ending(won: bool, elapsed: float, secret: bool = false) -> void:
	_game.hide()
	_menu.hide()
	_note.hide()
	_ending.show()
	_ending_kicker.text = "END OF TAPE  /  기록 회수 완료" if won else "SIGNAL LOST  /  기록자 실종"
	_ending_title.text = "신은 죽었다.\n우리가 죽였다." if won else "그것이 당신의\n기도를 들었다."
	if won and secret:
		_ending_body.text = "우리는 구원을 구한 적이 없었다.\n용서해 줄 목소리가 필요했을 뿐이다.\n당신은 마지막 기록을 들고 성당을 떠났다."
	elif won:
		_ending_body.text = "우리가 죽인 신은 우리의 기도로 썩어 갔다.\n봉인은 닫혔다. 그러나 문 너머에서,\n아직 당신의 이름을 부르는 소리가 들린다."
	else:
		_ending_body.text = "종이 울렸고, 어둠이 고개를 들었다.\n그것은 끝내 당신을 신도로 받아들였다.\n\n불을 끄고, 고개를 숙이십시오."
	_ending_metadata.text = "기록 길이  %02d:%02d   /   %s" % [int(elapsed) / 60, int(elapsed) % 60, "원본 진술 회수" if secret and won else ("회수 성공" if won else "회수 불가")]


func show_note(title: String, body: String) -> void:
	_note_serial += 1
	_note_title.text = title
	_note_body.text = body
	_note_index.text = "회수 문서  /  EVIDENCE %02d" % _note_serial
	_note.show()
	_prompt.text = ""


func close_note() -> void:
	_note.hide()


func set_status(objective: String, seals: int, battery: float, stamina: float, seconds: float) -> void:
	if not _built:
		return
	_objective.text = objective
	for i in range(_seal_labels.size()):
		_seal_labels[i].text = "◆" if i < seals else "◇"
		_seal_labels[i].add_theme_color_override("font_color", Color("d4d1ac") if i < seals else Color("67775d"))
	_battery.value = clampf(battery, 0.0, 1.0)
	_stamina.value = clampf(stamina, 0.0, 1.0)
	_battery_text.text = "LIGHT  /  %03d%%" % int(clampf(battery, 0.0, 1.0) * 100.0)
	_battery_text.add_theme_color_override("font_color", Color("ba7060") if battery < 0.2 else MUTED)
	_seconds = maxf(seconds, 0.0)


func set_prompt(text: String) -> void:
	if _built:
		_prompt.text = text


func set_subtitle(text: String) -> void:
	if _built:
		_subtitle.text = text
		_subtitle_backing.visible = not text.is_empty()


func set_threat(value: float) -> void:
	if _filter_material != null:
		_filter_material.set_shader_parameter("threat", clampf(value, 0.0, 1.0))


func set_vhs_strength(value: float) -> void:
	if _filter_material != null:
		_filter_material.set_shader_parameter("intensity", clampf(value, 0.0, 1.5))


func set_brightness(value: float) -> void:
	if _filter_material != null:
		_filter_material.set_shader_parameter("brightness", clampf(value, 0.6, 1.8))

func sync_settings(volume: float, sensitivity: float, brightness: float, vhs: float) -> void:
	var values := {"volume": volume, "sensitivity": sensitivity, "brightness": brightness}
	for key: String in values:
		if _sliders.has(key):
			_sliders[key].set_value_no_signal(values[key])
			_setting_labels[key].text = "%d%%" % int(float(values[key]) * 100.0)
	_reduced.set_pressed_no_signal(vhs < 0.4)
