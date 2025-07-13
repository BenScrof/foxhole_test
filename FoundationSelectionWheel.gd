# ============================================
# FoundationSelectionWheel.gd - VERSION SIMPLE QUI FONCTIONNE GARANTIE
# ============================================

extends Control
class_name FoundationSelectionWheel

# Types de fondations disponibles
enum FoundationType {
	NORMAL,
	RAMPE,
	COIN_RAMPE
}

# Configuration simple
@export var wheel_radius: float = 150.0
@export var center_radius: float = 40.0

# Données des fondations
var foundation_data: Array[Dictionary] = [
	{
		"type": FoundationType.NORMAL,
		"name": "Fondation",
		"icon": "🟫",
		"scene_path": "res://assets/models/fondation.tscn"
	},
	{
		"type": FoundationType.RAMPE,
		"name": "Rampe", 
		"icon": "🔺",
		"scene_path": "res://assets/models/rampe_test.tscn"
	},
	{
		"type": FoundationType.COIN_RAMPE,
		"name": "Coin Rampe",
		"icon": "📐", 
		"scene_path": "res://assets/models/coin_rampe.tscn"
	}
]

# État interne
var is_visible: bool = false
var current_hovered: int = -1
var selected_foundation: int = 0
var wheel_center: Vector2

# Signaux
signal foundation_selected(foundation_type: FoundationType, scene_path: String)
signal wheel_closed()

func _ready():
	print("🎡 Roue simple initialisée")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_wheel():
	"""Afficher la roue - version simple garantie"""
	print("🎡 === AFFICHAGE ROUE SIMPLE ===")
	
	is_visible = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Configuration forcée
	var screen_size = get_viewport().get_visible_rect().size
	size = screen_size
	position = Vector2.ZERO
	wheel_center = size * 0.5
	z_index = 1000
	
	print("🖥️ Écran:", screen_size)
	print("🎡 Centre:", wheel_center)
	
	# ✅ LIBÉRER LA SOURIS pour qu'elle soit visible et utilisable
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("🖱️ Souris libérée")
	
	# Forcer le redessin
	queue_redraw()

func hide_wheel():
	"""Cacher la roue"""
	print("🎡 Fermeture roue simple")
	is_visible = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	current_hovered = -1
	
	# ✅ RECAPTURER LA SOURIS pour la caméra FPS
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("🖱️ Souris recapturée pour FPS")
	
	wheel_closed.emit()

func _input(event):
	if not is_visible:
		return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F or event.keycode == KEY_ESCAPE:
			hide_wheel()
	
	elif event is InputEventMouseMotion:
		_update_hover(get_local_mouse_position())
	
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_select_current_foundation()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			hide_wheel()

func _update_hover(mouse_pos: Vector2):
	"""Mettre à jour le survol - version simple"""
	var distance = wheel_center.distance_to(mouse_pos)
	
	if distance < center_radius:
		current_hovered = -1
	elif distance <= wheel_radius:
		# Calculer quel segment
		var angle = (mouse_pos - wheel_center).angle()
		# Normaliser l'angle (commencer par le haut)
		angle += PI/2
		if angle < 0:
			angle += 2 * PI
		
		var segment = int(angle / (2 * PI / 3))  # 3 segments
		current_hovered = clamp(segment, 0, 2)
	else:
		current_hovered = -1
	
	queue_redraw()

func _select_current_foundation():
	"""Sélectionner la fondation actuelle"""
	if current_hovered >= 0 and current_hovered < foundation_data.size():
		var data = foundation_data[current_hovered]
		foundation_selected.emit(data.type, data.scene_path)
		print("✅ Sélectionné:", data.name)
		hide_wheel()

func _draw():
	"""Dessiner la roue - VERSION SIMPLE ET VISIBLE"""
	if not is_visible:
		return
	
	print("🎨 Dessin roue simple...")
	
	# FOND SEMI-TRANSPARENT VISIBLE
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.8))
	
	# CERCLE PRINCIPAL (contour blanc épais)
	draw_arc(wheel_center, wheel_radius, 0, 2 * PI, 64, Color.WHITE, 6.0)
	
	# CERCLE CENTRAL
	draw_circle(wheel_center, center_radius, Color(0.2, 0.2, 0.2, 0.9))
	draw_arc(wheel_center, center_radius, 0, 2 * PI, 32, Color.WHITE, 4.0)
	
	# TEXTE CENTRAL
	var font = ThemeDB.fallback_font
	_draw_text_centered("FONDATIONS", wheel_center, 18, Color.WHITE)
	
	# DESSINER LES 3 SEGMENTS
	for i in range(3):
		_draw_simple_segment(i)
	
	# LIGNES DE SÉPARATION
	for i in range(3):
		var angle = (i * 2 * PI / 3) - PI/2
		var start_pos = wheel_center + Vector2(cos(angle), sin(angle)) * center_radius
		var end_pos = wheel_center + Vector2(cos(angle), sin(angle)) * wheel_radius
		draw_line(start_pos, end_pos, Color.WHITE, 3.0)

func _draw_simple_segment(index: int):
	"""Dessiner un segment simple"""
	if index >= foundation_data.size():
		return
	
	var data = foundation_data[index]
	
	# Angle du centre du segment
	var angle = (index * 2 * PI / 3) - PI/2 + (PI/3)
	var distance = (center_radius + wheel_radius) * 0.5
	var pos = wheel_center + Vector2(cos(angle), sin(angle)) * distance
	
	# Couleur selon l'état
	var bg_color = Color(0.3, 0.3, 0.3, 0.8)
	if index == current_hovered:
		bg_color = Color(0.5, 0.8, 1.0, 0.9)  # Bleu vif
	elif index == selected_foundation:
		bg_color = Color(0.3, 0.9, 0.5, 0.9)  # Vert vif
	
	# Cercle de fond pour le segment
	draw_circle(pos, 50, bg_color)
	draw_arc(pos, 50, 0, 2 * PI, 32, Color.WHITE, 2.0)
	
	# Icône (grande et visible)
	_draw_text_centered(data.icon, pos + Vector2(0, -10), 28, Color.WHITE)
	
	# Nom (plus petit, en dessous)
	_draw_text_centered(data.name, pos + Vector2(0, 15), 12, Color.WHITE)

func _draw_text_centered(text: String, center_pos: Vector2, font_size: int, color: Color):
	"""Dessiner du texte centré"""
	var font = ThemeDB.fallback_font
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = center_pos - text_size * 0.5
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

# ============================================
# MÉTHODES PUBLIQUES SIMPLES
# ============================================

func is_wheel_visible() -> bool:
	return is_visible

func set_selected_foundation(foundation_type: FoundationType):
	for i in range(foundation_data.size()):
		if foundation_data[i].type == foundation_type:
			selected_foundation = i
			break

func get_selected_foundation_data() -> Dictionary:
	if selected_foundation >= 0 and selected_foundation < foundation_data.size():
		return foundation_data[selected_foundation]
	return {}
