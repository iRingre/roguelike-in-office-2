class_name GameHud
extends CanvasLayer

signal start_pressed
signal equipment_chosen(index: int)
signal restart_pressed

var health_label: Label
var wave_label: Label
var hint_label: Label
var weapon_label: Label
var scrap_label: Label
var equipment_label: Label
var crosshair: Label
var overlay: ColorRect
var remaining_count: int = 0

func _ready() -> void:
	_build_game_hud()
	show_intro()

func _build_game_hud() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	health_label = _label(root, "VITA  100 / 100", Vector2(28, 26), 22, Color(0.45, 0.95, 0.9))
	wave_label = _label(root, "PIANO  1 / 3  |  STANZA  1 / 6", Vector2(28, 58), 17, Color(0.75, 0.82, 0.95))
	weapon_label = _label(root, "ARMA  1 Pistola", Vector2(28, 84), 16, Color(0.55, 0.88, 1.0))
	scrap_label = _label(root, "ROTTAMI  0", Vector2(28, 108), 15, Color(0.92, 0.72, 0.42))
	equipment_label = _label(root, "EQUIPAGGIAMENTO  nessuno", Vector2(28, 131), 14, Color(0.7, 0.85, 0.92))
	hint_label = _label(root, "WASD muovi   SPAZIO salta   MOUSE spara   1-3 cambia arma trovata   ESC libera il mouse", Vector2(28, -42), 15, Color(0.65, 0.73, 0.84))
	hint_label.anchor_top = 1.0
	hint_label.anchor_bottom = 1.0
	crosshair = _label(root, "+", Vector2.ZERO, 30, Color(0.5, 1.0, 1.0))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-9, -18)

	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.015, 0.025, 0.055, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

func show_intro() -> void:
	_show_panel(
		"ULTIMO PIANO",
		"Sei un impiegato d'ufficio e il turno e finalmente finito. L'ascensore e fuori servizio: per tornare a casa dovrai scendere a piedi, attraversando tre piani del palazzo.\n\nOgni piano ha sei stanze, infestate da presenze risvegliate dal blackout. Dovrai liberarle tutte prima di poter scendere al piano successivo.\n\nIl percorso cambia a ogni partita. Cerca le armi luminose e usa i rottami per migliorare danni, salute e velocita nell'ufficio manutenzione. Alla fine del terzo piano ti aspetta il Direttore.",
		"TORNA A CASA",
		func(): start_pressed.emit(),
		450.0
	)

func set_room(room_index: int, total_floors: int, rooms_per_floor: int, unlocked_doors: int) -> void:
	var floor_number := floori(float(room_index) / float(rooms_per_floor)) + 1
	var room_number := room_index % rooms_per_floor + 1
	wave_label.text = "PIANO  %d / %d   |   STANZA  %d / %d   |   PORTE APERTE %d" % [floor_number, total_floors, room_number, rooms_per_floor, unlocked_doors]
	hint_label.text = "PRESENZE  %d   |   WASD muovi   MOUSE spara   1-3 armi trovate   ESC libera il mouse" % remaining_count

func close_intro() -> void:
	_clear_panel()

func show_message(message: String) -> void:
	var root := get_child(0) as Control
	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-290, 92)
	box.custom_minimum_size = Vector2(580, 76)
	box.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.09, 0.16, 0.93), Color(0.18, 0.75, 0.85)))
	root.add_child(box)
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.78, 0.92, 0.98))
	box.add_child(label)
	var timer := get_tree().create_timer(4.0)
	timer.timeout.connect(_remove_message.bind(box))

func show_workshop(floor_number: int, room_number: int, rooms_per_floor: int, total_floors: int, story: String, scrap: int) -> void:
	_show_panel(
		"UFFICIO MANUTENZIONE",
		"%s\n\nHai %d rottami. Puoi creare equipaggiamento (costo: 3) oppure proseguire." % [story, scrap],
		"",
		func(): pass,
		330.0
	)
	var root := get_child(0) as Control
	var buttons := VBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_CENTER)
	buttons.position = Vector2(-220, 105)
	buttons.custom_minimum_size = Vector2(440, 235)
	buttons.add_theme_constant_override("separation", 5)
	root.add_child(buttons)
	var choices := [
		"Crea modulo balistico   +8 danni",
		"Crea corazza d'eco   +30 vita massima",
		"Crea stivali inerziali   +1.4 velocita"
	]
	for index in range(choices.size()):
		var button := _make_button("%s   |   3 rottami" % choices[index])
		button.disabled = scrap < 3
		buttons.add_child(button)
		button.pressed.connect(_emit_equipment_choice.bind(index))
	var continue_button := _make_button("Continua l'esplorazione")
	buttons.add_child(continue_button)
	continue_button.pressed.connect(_emit_equipment_choice.bind(3))
	wave_label.text = "MANUTENZIONE  |  PIANO %d / %d  •  STANZA %d / %d" % [floor_number, total_floors, room_number, rooms_per_floor]

func show_ending(victory: bool) -> void:
	var title := "SEI A CASA" if victory else "IL PALAZZO TI HA INGHIOTTITO"
	var text := "Dopo aver liberato i tre piani e sconfitto il Direttore, raggiungi finalmente l'uscita. L'aria della notte e fresca: il turno e finito e puoi tornare a casa." if victory else "Le porte del palazzo si richiudono e la strada di casa sembra ancora lontana.\n\nRiprova: il percorso cambia a ogni discesa."
	_show_panel(title, text, "RICOMINCIA", func(): restart_pressed.emit())
	wave_label.text = "USCITA RAGGIUNTA" if victory else "FINE DEL TURNO"

func set_health(current: float, maximum: float) -> void:
	health_label.text = "VITA  %d / %d" % [roundi(current), roundi(maximum)]
	health_label.add_theme_color_override("font_color", Color(1.0, 0.38, 0.42) if current <= maximum * 0.3 else Color(0.45, 0.95, 0.9))

func set_remaining(count: int) -> void:
	remaining_count = count
	hint_label.text = "PRESENZE  %d   |   WASD muovi   MOUSE spara   1-3 armi trovate" % count

func set_weapon(weapon_name: String, weapon_index: int) -> void:
	weapon_label.text = "ARMA  %d %s" % [weapon_index + 1, weapon_name]

func set_scrap(amount: int) -> void:
	scrap_label.text = "ROTTAMI  %d" % amount

func set_equipment(items: Array[String]) -> void:
	equipment_label.text = "EQUIPAGGIAMENTO  %s" % (", ".join(PackedStringArray(items)) if not items.is_empty() else "nessuno")

func _show_panel(title: String, text: String, button_text: String, callback: Callable, panel_height: float = 360.0) -> void:
	_clear_panel()
	var root := get_child(0) as Control
	overlay.visible = true
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-270, -panel_height / 2.0)
	panel.custom_minimum_size = Vector2(540, panel_height)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.06, 0.12, 0.98), Color(0.14, 0.72, 0.84)))
	root.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	panel.add_child(content)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color(0.42, 0.94, 1.0))
	content.add_child(heading)
	var body := Label.new()
	body.text = text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", Color(0.79, 0.85, 0.95))
	content.add_child(body)
	if not button_text.is_empty():
		var button := _make_button(button_text)
		content.add_child(button)
		button.pressed.connect(callback)
	overlay.visible = true
	crosshair.visible = false

func _remove_message(box: Control) -> void:
	if is_instance_valid(box):
		box.queue_free()

func _emit_equipment_choice(index: int) -> void:
	equipment_chosen.emit(index)

func close_workshop() -> void:
	_clear_panel()

func _clear_panel() -> void:
	var root := get_child(0) as Control
	for child in root.get_children():
		if child == health_label or child == wave_label or child == hint_label or child == weapon_label or child == scrap_label or child == equipment_label or child == crosshair or child == overlay:
			continue
		child.queue_free()
	overlay.visible = false
	crosshair.visible = true

func _label(parent: Control, text: String, position: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(0.85, 0.98, 1.0))
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.08, 0.2, 0.29), Color(0.18, 0.67, 0.78)))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.12, 0.34, 0.43), Color(0.35, 0.9, 1.0)))
	return button

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style
