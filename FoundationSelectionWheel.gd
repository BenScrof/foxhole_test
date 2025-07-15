# ============================================
# FoundationSelectionWheel.gd - Version WFC avec Tous les Bâtiments
# ============================================

extends Control
class_name FoundationSelectionWheel

enum FoundationType {
	NORMAL,
	RAMPE,
	COIN_RAMPE
}

enum ItemCategory {
	FOUNDATION,
	BUILDING
}

@export var wheel_radius: float = 160.0
@export var center_radius: float = 45.0

# Données combinées (fondations + bâtiments WFC)
var all_items: Array[Dictionary] = [
	# === FONDATIONS ===
	{
		"type": FoundationType.NORMAL,
		"category": ItemCategory.FOUNDATION,
		"name": "Fondation",
		"icon": "🟫",
		"scene_path": "res://assets/models/fondation.tscn",
		"color": Color(0.6, 0.6, 0.6)
	},
	{
		"type": FoundationType.RAMPE,
		"category": ItemCategory.FOUNDATION,
		"name": "Rampe", 
		"icon": "🔺",
		"scene_path": "res://assets/models/rampe_test.tscn",
		"color": Color(0.6, 0.6, 0.6)
	},
	{
		"type": FoundationType.COIN_RAMPE,
		"category": ItemCategory.FOUNDATION,
		"name": "Coin Rampe",
		"icon": "📐", 
		"scene_path": "res://assets/models/coin_rampe.tscn",
		"color": Color(0.6, 0.6, 0.6)
	},
	
	# === BÂTIMENTS WFC ===
	{
		"type": BuildingSystem.BuildingType.MUR_DROIT,
		"category": ItemCategory.BUILDING,
		"name": "Mur Droit",
		"icon": "🧱",
		"scene_path": "res://assets/models/mur_droit.tscn",
		"color": Color(0.8, 0.4, 0.2)
	},
	{
		"type": BuildingSystem.BuildingType.MUR_COIN,
		"category": ItemCategory.BUILDING,
		"name": "Mur Coin",
		"icon": "📐",
		"scene_path": "res://assets/models/mur_coin.tscn",
		"color": Color(0.8, 0.4, 0.2)
	},
	{
		"type": BuildingSystem.BuildingType.MUR_PORTE,
		"category": ItemCategory.BUILDING,
		"name": "Mur Porte",
		"icon": "🚪",
		"scene_path": "res://assets/models/mur_porte.tscn",
		"color": Color(0.4, 0.8, 0.4)
	},
	{
		"type": BuildingSystem.BuildingType.MUR_FENETRE,
		"category": ItemCategory.BUILDING,
		"name": "Mur Fenêtre",
		"icon": "🪟",
		"scene_path": "res://assets/models/mur_fenetre.tscn",
		"color": Color(0.4, 0.6, 0.8)
	}
]

var is_wheel_visible: bool = false
var current_hovered: int = -1
var selected_item: int = 0
var wheel_center: Vector2

# Signaux
signal foundation_selected(foundation_type: FoundationType, scene_path: String)
signal building_selected(building_type: BuildingSystem.BuildingType, scene_path: String)
signal wheel_closed()

func _ready():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_wheel():
	is_wheel_visible = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	var screen_size = get_viewport().get_visible_rect().size
	size = screen_size
	position = Vector2.ZERO
	wheel_center = size * 0.5
	z_index = 1000
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	queue_redraw()

func hide_wheel():
	is_wheel_visible = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	current_hovered = -1
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	wheel_closed.emit()

func _input(event):
	if not is_wheel_visible:
		return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F or event.keycode == KEY_ESCAPE:
			hide_wheel()
	
	elif event is InputEventMouseMotion:
		_update_hover(get_local_mouse_position())
	
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_select_current_item()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			hide_wheel()
			get_viewport().set_input_as_handled()

func _update_hover(mouse_pos: Vector2):
	var distance = wheel_center.distance_to(mouse_pos)
	
	if distance < center_radius:
		current_hovered = -1
	elif distance <= wheel_radius:
		var angle = (mouse_pos - wheel_center).angle()
		angle += PI/2
		if angle < 0:
			angle += 2 * PI
		
		var segment = int(angle / (2 * PI / all_items.size()))
		current_hovered = clamp(segment, 0, all_items.size() - 1)
	else:
		current_hovered = -1
	
	queue_redraw()

func _select_current_item():
	if current_hovered >= 0 and current_hovered < all_items.size():
		var data = all_items[current_hovered]
		selected_item = current_hovered
		
		match data.category:
			ItemCategory.FOUNDATION:
				foundation_selected.emit(data.type, data.scene_path)
			ItemCategory.BUILDING:
				building_selected.emit(data.type, data.scene_path)
		
		hide_wheel()

func _draw():
	if not is_wheel_visible:
		return
	
	# Fond semi-transparent
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85))
	
	# Cercle principal externe
	draw_arc(wheel_center, wheel_radius, 0, 2 * PI, 64, Color.WHITE, 8.0)
	
	# Cercle central
	draw_circle(wheel_center, center_radius, Color(0.15, 0.15, 0.15, 0.95))
	draw_arc(wheel_center, center_radius, 0, 2 * PI, 32, Color.WHITE, 5.0)
	
	# Texte central avec info
	_draw_text_centered("CONSTRUCTION", wheel_center - Vector2(0, 8), 18, Color.WHITE)
	_draw_text_centered("WFC", wheel_center + Vector2(0, 12), 14, Color(0.8, 0.8, 0.8))
	
	# Segments pour chaque item
	for i in range(all_items.size()):
		_draw_item_segment(i)
	
	# Lignes de séparation
	for i in range(all_items.size()):
		var angle = (i * 2 * PI / all_items.size()) - PI/2
		var start_pos = wheel_center + Vector2(cos(angle), sin(angle)) * center_radius
		var end_pos = wheel_center + Vector2(cos(angle), sin(angle)) * wheel_radius
		draw_line(start_pos, end_pos, Color.WHITE, 3.0)
	
	# Afficher info de l'item survolé
	if current_hovered >= 0:
		_draw_hover_info()

func _draw_item_segment(index: int):
	if index >= all_items.size():
		return
	
	var data = all_items[index]
	
	var angle = (index * 2 * PI / all_items.size()) - PI/2 + (PI / all_items.size())
	var distance = (center_radius + wheel_radius) * 0.5
	var pos = wheel_center + Vector2(cos(angle), sin(angle)) * distance
	
	# Couleur selon catégorie et état
	var bg_color = data.get("color", Color(0.4, 0.4, 0.4))
	bg_color.a = 0.8
	
	# États visuels
	if index == current_hovered:
		bg_color = Color(1.0, 1.0, 1.0, 0.9)  # Blanc brillant
	elif index == selected_item:
		bg_color = Color(0.2, 1.0, 0.2, 0.9)  # Vert vif
	
	# Taille du segment selon catégorie
	var segment_radius = 42
	if data.category == ItemCategory.BUILDING:
		segment_radius = 45  # Légèrement plus grand pour bâtiments
	
	# Fond du segment avec dégradé
	draw_circle(pos, segment_radius + 2, Color.BLACK.darkened(0.3))
	draw_circle(pos, segment_radius, bg_color)
	
	# Contour selon l'état
	var border_color = Color.WHITE
	var border_width = 2.0
	if index == current_hovered:
		border_color = Color.YELLOW
		border_width = 4.0
	elif index == selected_item:
		border_color = Color.GREEN
		border_width = 3.0
	
	draw_arc(pos, segment_radius, 0, 2 * PI, 32, border_color, border_width)
	
	# Icône principale
	var icon_color = Color.WHITE
	if index == current_hovered:
		icon_color = Color.BLACK
	
	_draw_text_centered(data.icon, pos - Vector2(0, 8), 24, icon_color)
	
	# Nom du type
	var name_color = Color.WHITE
	if index == current_hovered:
		name_color = Color.BLACK
	
	_draw_text_centered(data.name, pos + Vector2(0, 12), 10, name_color)
	
	# Indicateur de catégorie
	var category_indicator = "F" if data.category == ItemCategory.FOUNDATION else "B"
	var indicator_color = Color(0.7, 0.7, 0.7)
	if index == current_hovered:
		indicator_color = Color(0.3, 0.3, 0.3)
	
	_draw_text_centered(category_indicator, pos + Vector2(0, 24), 8, indicator_color)

func _draw_hover_info():
	"""Affiche des informations détaillées sur l'item survolé"""
	if current_hovered < 0 or current_hovered >= all_items.size():
		return
	
	var data = all_items[current_hovered]
	var info_pos = Vector2(wheel_center.x + wheel_radius + 50, wheel_center.y - 100)
	
	# Fond d'information
	var info_size = Vector2(200, 120)
	draw_rect(Rect2(info_pos, info_size), Color(0, 0, 0, 0.9))
	draw_rect(Rect2(info_pos, info_size), Color.WHITE, false, 2.0)
	
	# Titre
	_draw_text_centered(data.name, info_pos + Vector2(100, 20), 16, Color.WHITE)
	
	# Catégorie
	var category_text = "Fondation" if data.category == ItemCategory.FOUNDATION else "Bâtiment WFC"
	_draw_text_centered(category_text, info_pos + Vector2(100, 40), 12, Color(0.8, 0.8, 0.8))
	
	# Informations spécifiques
	if data.category == ItemCategory.BUILDING:
		_draw_text_centered("• Snap automatique", info_pos + Vector2(100, 60), 10, Color(0.6, 1.0, 0.6))
		_draw_text_centered("• Règles WFC", info_pos + Vector2(100, 75), 10, Color(0.6, 1.0, 0.6))
		_draw_text_centered("• Sur fondation", info_pos + Vector2(100, 90), 10, Color(0.6, 1.0, 0.6))
	else:
		_draw_text_centered("• Snap aux côtés", info_pos + Vector2(100, 60), 10, Color(0.6, 0.8, 1.0))
		_draw_text_centered("• Alignement auto", info_pos + Vector2(100, 75), 10, Color(0.6, 0.8, 1.0))
		_draw_text_centered("• Base construction", info_pos + Vector2(100, 90), 10, Color(0.6, 0.8, 1.0))

func _draw_text_centered(text: String, center_pos: Vector2, font_size: int, color: Color):
	var font = ThemeDB.fallback_font
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = center_pos - text_size * 0.5
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

# ============================================
# Méthodes publiques
# ============================================

func is_wheel_open() -> bool:
	return is_wheel_visible

func get_selected_item_data() -> Dictionary:
	if selected_item >= 0 and selected_item < all_items.size():
		return all_items[selected_item]
	return {}

func get_foundation_count() -> int:
	return all_items.filter(func(item): return item.category == ItemCategory.FOUNDATION).size()

func get_building_count() -> int:
	return all_items.filter(func(item): return item.category == ItemCategory.BUILDING).size()

func set_selected_item_by_type(category: ItemCategory, type_value):
	"""Sélectionne un item par sa catégorie et son type"""
	for i in range(all_items.size()):
		var item = all_items[i]
		if item.category == category and item.type == type_value:
			selected_item = i
			break
