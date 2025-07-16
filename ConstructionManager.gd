# ============================================
# ConstructionManager.gd - SYSTÈME SIMPLIFIÉ V3.0
# ============================================

extends Node3D
class_name ConstructionManager

# ============================================
# CONFIGURATION
# ============================================

@export var foundation_size: float = 4.0
@export var max_build_distance: float = 15.0
@export var snap_distance: float = 2.0
@export var preview_alpha: float = 0.6

# ============================================
# ÉNUMÉRATIONS
# ============================================

enum BuildMode {
	INACTIVE,
	SELECTING,
	BUILDING_FOUNDATION,
	BUILDING_STRUCTURE
}

enum ConstructionType {
	FOUNDATION,
	BUILDING
}

# ============================================
# CATALOGUE DES OBJETS
# ============================================

# Catalogue des fondations
var foundation_catalog: Dictionary = {
	0: {  # FONDATION_NORMALE
		"name": "Fondation",
		"scene_path": "res://assets/models/fondation.tscn",
		"icon": "🟫",
		"size": Vector3(4, 0.2, 4),
		"snap_points": ["Top", "Side_North", "Side_South", "Side_East", "Side_West"],
		"type": "foundation"
	},
	1: {  # RAMPE
		"name": "Rampe",
		"scene_path": "res://assets/models/rampe_test.tscn",
		"icon": "🔺",
		"size": Vector3(2, 0.2, 4),
		"snap_points": ["Entry"],
		"type": "foundation"
	},
	2: {  # COIN_RAMPE
		"name": "Coin Rampe",
		"scene_path": "res://assets/models/coin_rampe.tscn",
		"icon": "📐",
		"size": Vector3(1, 1, 0.2),
		"snap_points": [],
		"type": "foundation"
	}
}

# Catalogue des bâtiments
var building_catalog: Dictionary = {
	0: {  # MUR_DROIT
		"name": "Mur Droit",
		"scene_path": "res://assets/models/mur_droit.tscn",
		"icon": "🧱",
		"size": Vector3(0.1, 2, 1),
		"snap_faces": ["north", "south"],
		"can_connect_to": [0, 1, 2, 3],
		"type": "building"
	},
	1: {  # MUR_COIN
		"name": "Mur Coin",
		"scene_path": "res://assets/models/mur_coin.tscn",
		"icon": "📐",
		"size": Vector3(1, 2, 1),
		"snap_faces": ["north", "south", "east", "west"],
		"can_connect_to": [0, 1, 2, 3],
		"type": "building"
	},
	2: {  # MUR_PORTE
		"name": "Mur Porte",
		"scene_path": "res://assets/models/mur_porte.tscn",
		"icon": "🚪",
		"size": Vector3(0.1, 2, 1),
		"snap_faces": ["north", "south"],
		"can_connect_to": [0, 1, 2, 3],
		"type": "building"
	},
	3: {  # MUR_FENETRE
		"name": "Mur Fenêtre",
		"scene_path": "res://assets/models/mur_fenetre.tscn",
		"icon": "🪟",
		"size": Vector3(0.1, 2, 1),
		"snap_faces": ["north", "south"],
		"can_connect_to": [0, 1, 2, 3],
		"type": "building"
	}
}

# Règles de connexion entre faces
var connection_rules: Dictionary = {
	"north": ["south"],
	"south": ["north"],
	"east": ["west"],
	"west": ["east"]
}

# ============================================
# VARIABLES D'ÉTAT
# ============================================

var current_build_mode: BuildMode = BuildMode.INACTIVE
var current_construction_type: ConstructionType = ConstructionType.FOUNDATION
var selected_building_type: int = 0
var selected_foundation_type: int = 0  # Pour les fondations
var current_rotation: float = 0.0
var rotation_step: float = 90.0

# Preview
var preview_object: MeshInstance3D
var preview_valid: bool = false
var preview_position: Vector3
var current_snap_result: Dictionary = {}

# Matériaux
var preview_material_valid: StandardMaterial3D
var preview_material_invalid: StandardMaterial3D

# Références
var player: Player
var camera: Camera3D
var terrain_manager: TerrainManager
var selection_wheel: FoundationSelectionWheel
var construction_ui: Control
var info_label: Label

# Données
var placed_buildings: Array[Dictionary] = []
var placed_foundations: Array[Dictionary] = []

# ============================================
# INITIALISATION
# ============================================

func _ready():
	add_to_group("construction_manager")
	_setup_materials()
	_setup_preview()
	
	await get_tree().process_frame
	_find_references()
	call_deferred("_setup_ui")

func _setup_materials():
	"""Configure les matériaux de preview"""
	preview_material_valid = StandardMaterial3D.new()
	preview_material_valid.albedo_color = Color(0.3, 1.0, 0.3, preview_alpha)
	preview_material_valid.flags_transparent = true
	
	preview_material_invalid = StandardMaterial3D.new()
	preview_material_invalid.albedo_color = Color(1.0, 0.3, 0.3, preview_alpha)
	preview_material_invalid.flags_transparent = true

func _setup_preview():
	"""Configure l'objet de preview"""
	preview_object = MeshInstance3D.new()
	add_child(preview_object)
	preview_object.visible = false

func _find_references():
	"""Trouve les références nécessaires"""
	player = get_tree().get_first_node_in_group("player")
	terrain_manager = get_tree().get_first_node_in_group("world")
	
	if player:
		camera = player.get_node("Head/Camera3D")

func _setup_ui():
	"""Configure l'interface utilisateur"""
	# Menu de sélection
	selection_wheel = FoundationSelectionWheel.new()
	selection_wheel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selection_wheel.z_index = 1000
	
	get_tree().root.add_child(selection_wheel)
	
	# Connecter signaux
	selection_wheel.building_selected.connect(_on_building_selected)
	selection_wheel.wheel_closed.connect(_on_wheel_closed)
	
	# UI d'information
	construction_ui = Control.new()
	construction_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(construction_ui)
	
	info_label = Label.new()
	info_label.position = Vector2(20, 100)
	info_label.size = Vector2(400, 300)
	info_label.add_theme_color_override("font_color", Color.YELLOW)
	info_label.add_theme_font_size_override("font_size", 16)
	construction_ui.add_child(info_label)
	construction_ui.visible = false

# ============================================
# SYSTÈME DE SNAP
# ============================================

func find_snap_position(object_type: int, target_position: Vector3, construction_type: ConstructionType) -> Dictionary:
	"""Trouve la meilleure position de snap disponible"""
	var best_snap = {}
	var min_distance = snap_distance
	
	# Chercher dans les bâtiments existants
	for building_data in placed_buildings:
		if not building_data.node or not is_instance_valid(building_data.node):
			continue
		
		var snap_points = _get_all_snap_points(building_data.node)
		
		for point_name in snap_points:
			var point_data = snap_points[point_name]
			var distance = target_position.distance_to(point_data.position)
			
			if distance < min_distance:
				if _can_objects_connect(object_type, construction_type, point_name, building_data.type, ConstructionType.BUILDING):
					var snap_position = _calculate_snap_position_universal(object_type, construction_type, point_data, point_name)
					
					best_snap = {
						"valid": true,
						"position": snap_position,
						"point_name": point_name,
						"distance": distance,
						"target_object": building_data.node
					}
					min_distance = distance
	
	# Chercher dans les fondations existantes
	for foundation_data in placed_foundations:
		if not foundation_data.node or not is_instance_valid(foundation_data.node):
			continue
		
		var snap_points = _get_all_snap_points(foundation_data.node)
		
		for point_name in snap_points:
			var point_data = snap_points[point_name]
			var distance = target_position.distance_to(point_data.position)
			
			if distance < min_distance:
				if _can_objects_connect(object_type, construction_type, point_name, foundation_data.type, ConstructionType.FOUNDATION):
					var snap_position = _calculate_snap_position_universal(object_type, construction_type, point_data, point_name)
					
					best_snap = {
						"valid": true,
						"position": snap_position,
						"point_name": point_name,
						"distance": distance,
						"target_object": foundation_data.node
					}
					min_distance = distance
	
	return best_snap

func _get_all_snap_points(object_node: Node3D) -> Dictionary:
	"""Extrait tous les points de snap d'un objet (SnapFace_ ou SnapPoint_)"""
	var points = {}
	
	for child in object_node.get_children():
		# Gérer les SnapFace_ (Area3D) pour les bâtiments
		if child.name.begins_with("SnapFace_") and child is Area3D:
			var point_name = child.name.replace("SnapFace_", "")
			points[point_name] = {
				"position": child.global_position,
				"normal": _get_face_normal(point_name),
				"type": "face",
				"node": child
			}
		
		# Gérer les SnapPoint_ (Node3D) pour les fondations
		elif child.name.begins_with("SnapPoint_") and child is Node3D:
			var point_name = child.name.replace("SnapPoint_", "")
			points[point_name] = {
				"position": child.global_position,
				"normal": _get_point_normal(point_name),
				"type": "point",
				"node": child
			}
	
	return points

func _get_snap_faces(building_node: Node3D) -> Dictionary:
	"""Extrait toutes les SnapFaces d'un bâtiment (legacy)"""
	return _get_all_snap_points(building_node)

func _get_face_normal(face_name: String) -> Vector3:
	"""Retourne la normale d'une face de bâtiment"""
	match face_name:
		"north": return Vector3(0, 0, 1)
		"south": return Vector3(0, 0, -1)
		"east": return Vector3(1, 0, 0)
		"west": return Vector3(-1, 0, 0)
		_: return Vector3.ZERO

func _get_point_normal(point_name: String) -> Vector3:
	"""Retourne la normale d'un point de fondation"""
	match point_name:
		"Top": return Vector3(0, 1, 0)
		"Side_North": return Vector3(0, 0, 1)
		"Side_South": return Vector3(0, 0, -1)
		"Side_East": return Vector3(1, 0, 0)
		"Side_West": return Vector3(-1, 0, 0)
		"Entry": return Vector3(1, 0, 0)  # Pour les rampes
		_: return Vector3.ZERO

func _can_objects_connect(my_type: int, my_construction_type: ConstructionType, other_point: String, other_type: int, other_construction_type: ConstructionType) -> bool:
	"""Vérifie si deux objets peuvent se connecter"""
	
	# Connexion fondation-fondation
	if my_construction_type == ConstructionType.FOUNDATION and other_construction_type == ConstructionType.FOUNDATION:
		return _can_foundations_connect(my_type, other_point, other_type)
	
	# Connexion bâtiment-bâtiment
	elif my_construction_type == ConstructionType.BUILDING and other_construction_type == ConstructionType.BUILDING:
		return _can_buildings_connect(my_type, other_point, other_type)
	
	# Connexion bâtiment-fondation (bâtiment sur fondation)
	elif my_construction_type == ConstructionType.BUILDING and other_construction_type == ConstructionType.FOUNDATION:
		return other_point == "Top"  # Les bâtiments ne peuvent se poser que sur le Top des fondations
	
	return false

func _can_foundations_connect(my_type: int, other_point: String, other_type: int) -> bool:
	"""Vérifie si deux fondations peuvent se connecter"""
	# Les fondations peuvent se connecter par leurs côtés
	return other_point.begins_with("Side_")

func _can_buildings_connect(my_type: int, other_point: String, other_type: int) -> bool:
	"""Vérifie si deux bâtiments peuvent se connecter"""
	var my_data = building_catalog.get(my_type, {})
	var other_data = building_catalog.get(other_type, {})
	
	# Vérifier si les types sont compatibles
	var my_connections = my_data.get("can_connect_to", [])
	if not other_type in my_connections:
		return false
	
	# Vérifier si les faces sont compatibles
	var my_face = _get_opposite_face(other_point)
	var my_faces = my_data.get("snap_faces", [])
	if not my_face in my_faces:
		return false
	
	# Vérifier les règles de connexion
	var allowed_faces = connection_rules.get(my_face, [])
	return other_point in allowed_faces

func _can_connect(my_type: int, other_face: String, other_type: int) -> bool:
	"""Vérifie si deux objets peuvent se connecter (legacy)"""
	return _can_buildings_connect(my_type, other_face, other_type)

func _get_opposite_face(face_name: String) -> String:
	"""Retourne la face opposée"""
	match face_name:
		"north": return "south"
		"south": return "north"
		"east": return "west"
		"west": return "east"
		_: return ""

func _calculate_snap_position_universal(object_type: int, construction_type: ConstructionType, target_point: Dictionary, target_point_name: String) -> Vector3:
	"""Calcule la position exacte pour le snap universel"""
	
	if construction_type == ConstructionType.BUILDING:
		var building_data = building_catalog[object_type]
		var building_size = building_data.size
		var target_pos = target_point.position
		var target_normal = target_point.normal
		
		# Pour bâtiment sur fondation (Top)
		if target_point_name == "Top":
			return Vector3(target_pos.x, target_pos.y + building_size.y * 0.5, target_pos.z)
		
		# Pour bâtiment à bâtiment
		var offset = Vector3.ZERO
		match target_point_name:
			"north", "south":
				offset = target_normal * (building_size.z * 0.5)
			"east", "west":
				offset = target_normal * (building_size.x * 0.5)
		
		return target_pos + offset
	
	elif construction_type == ConstructionType.FOUNDATION:
		var foundation_data = foundation_catalog[object_type]
		var foundation_size = foundation_data.size
		var target_pos = target_point.position
		var target_normal = target_point.normal
		
		# Pour fondation à fondation
		var offset = Vector3.ZERO
		match target_point_name:
			"Side_North", "Side_South":
				offset = target_normal * (foundation_size.z * 0.5)
			"Side_East", "Side_West":
				offset = target_normal * (foundation_size.x * 0.5)
		
		return target_pos + offset
	
	return target_point.position

func _calculate_snap_position(building_type: int, target_face: Dictionary, target_face_name: String) -> Vector3:
	"""Calcule la position exacte pour le snap (legacy)"""
	return _calculate_snap_position_universal(building_type, ConstructionType.BUILDING, target_face, target_face_name)

# ============================================
# LOGIQUE DE PLACEMENT
# ============================================

func can_place_object(object_type: int, position: Vector3, construction_type: ConstructionType) -> Dictionary:
	"""Vérifie si un objet peut être placé"""
	var result = {"valid": true, "reason": "OK"}
	
	if construction_type == ConstructionType.BUILDING:
		# Les bâtiments doivent être sur une fondation
		if not _is_on_foundation(position):
			result.valid = false
			result.reason = "Doit être sur une fondation"
			return result
		
		# Vérifier les collisions (sauf si snap valide)
		if current_snap_result.is_empty() and _has_collision_building(object_type, position):
			result.valid = false
			result.reason = "Collision détectée"
	
	elif construction_type == ConstructionType.FOUNDATION:
		# Vérifier les collisions pour fondations
		if current_snap_result.is_empty() and _has_collision_foundation(object_type, position):
			result.valid = false
			result.reason = "Collision détectée"
	
	return result

func can_place_building(building_type: int, position: Vector3) -> Dictionary:
	"""Vérifie si un bâtiment peut être placé (legacy)"""
	return can_place_object(building_type, position, ConstructionType.BUILDING)

func place_object(object_type: int, position: Vector3, rotation: float, construction_type: ConstructionType) -> bool:
	"""Place un objet (fondation ou bâtiment)"""
	
	var catalog = foundation_catalog if construction_type == ConstructionType.FOUNDATION else building_catalog
	var object_data = catalog[object_type]
	var scene_path = object_data.scene_path
	
	# Charger la scène
	if not ResourceLoader.exists(scene_path):
		print("❌ Scène non trouvée: ", scene_path)
		return false
	
	var scene = load(scene_path)
	var object_instance = scene.instantiate()
	
	# Configurer l'instance
	object_instance.name = object_data.name + "_" + str(_get_object_count(construction_type))
	var group_name = "foundations" if construction_type == ConstructionType.FOUNDATION else "buildings"
	object_instance.add_to_group(group_name)
	
	# Ajouter à la scène
	get_tree().root.add_child(object_instance)
	object_instance.global_position = position
	object_instance.rotation_degrees.y = rotation
	
	# Enregistrer
	var object_record = {
		"node": object_instance,
		"type": object_type,
		"position": position,
		"rotation": rotation
	}
	
	if construction_type == ConstructionType.FOUNDATION:
		placed_foundations.append(object_record)
	else:
		placed_buildings.append(object_record)
	
	print("✅ ", object_data.name, " placé à ", position)
	return true

func place_building(building_type: int, position: Vector3, rotation: float = 0.0) -> bool:
	"""Place un bâtiment (legacy)"""
	return place_object(building_type, position, rotation, ConstructionType.BUILDING)

func place_foundation(foundation_type: int, position: Vector3, rotation: float = 0.0) -> bool:
	"""Place une fondation"""
	return place_object(foundation_type, position, rotation, ConstructionType.FOUNDATION)

func _get_object_count(construction_type: ConstructionType) -> int:
	"""Retourne le nombre d'objets d'un type donné"""
	if construction_type == ConstructionType.FOUNDATION:
		return placed_foundations.size()
	else:
		return placed_buildings.size()

func _is_on_foundation(position: Vector3) -> bool:
	"""Vérifie si la position est sur une fondation"""
	for foundation_data in placed_foundations:
		if not foundation_data.node or not is_instance_valid(foundation_data.node):
			continue
		
		var foundation_pos = foundation_data.node.global_position
		var distance = Vector2(position.x, position.z).distance_to(Vector2(foundation_pos.x, foundation_pos.z))
		
		if distance <= foundation_size * 0.6:
			return true
	
	return false

func _has_collision_building(building_type: int, position: Vector3) -> bool:
	"""Vérifie les collisions avec d'autres bâtiments"""
	var building_data = building_catalog[building_type]
	var building_size = building_data.size
	
	for other_building in placed_buildings:
		if not other_building.node or not is_instance_valid(other_building.node):
			continue
		
		var other_pos = other_building.position
		var distance = Vector2(position.x, position.z).distance_to(Vector2(other_pos.x, other_pos.z))
		
		# Distance minimum basée sur la taille des objets
		var min_distance = (building_size.x + building_size.z) * 0.3
		if distance < min_distance:
			return true
	
	return false

func _has_collision_foundation(foundation_type: int, position: Vector3) -> bool:
	"""Vérifie les collisions avec d'autres fondations"""
	var foundation_data = foundation_catalog[foundation_type]
	var foundation_size = foundation_data.size
	
	for other_foundation in placed_foundations:
		if not other_foundation.node or not is_instance_valid(other_foundation.node):
			continue
		
		var other_pos = other_foundation.position
		var distance = Vector2(position.x, position.z).distance_to(Vector2(other_pos.x, other_pos.z))
		
		# Distance minimum basée sur la taille des objets
		var min_distance = (foundation_size.x + foundation_size.z) * 0.4
		if distance < min_distance:
			return true
	
	return false

func _has_collision(building_type: int, position: Vector3) -> bool:
	"""Vérifie les collisions avec d'autres bâtiments (legacy)"""
	return _has_collision_building(building_type, position)

# ============================================
# SYSTÈME DE PREVIEW
# ============================================

func _update_preview():
	"""Met à jour le preview en temps réel"""
	if current_build_mode not in [BuildMode.BUILDING_FOUNDATION, BuildMode.BUILDING_STRUCTURE]:
		return
	
	if not player or not camera:
		return
	
	# Calculer la position cible
	var target_position = _calculate_target_position()
	if target_position == Vector3.INF:
		preview_object.visible = false
		return
	
	var object_type = selected_foundation_type if current_construction_type == ConstructionType.FOUNDATION else selected_building_type
	
	# Chercher un snap possible
	current_snap_result = find_snap_position(object_type, target_position, current_construction_type)
	
	# Déterminer la position finale
	var final_position = target_position
	if current_snap_result.get("valid", false):
		final_position = current_snap_result.position
		preview_position = final_position
	else:
		if current_construction_type == ConstructionType.BUILDING:
			# Ajuster la hauteur pour être sur la fondation
			var foundation_height = _get_foundation_height_at(Vector2(target_position.x, target_position.z))
			if foundation_height > -999:
				final_position = Vector3(target_position.x, foundation_height, target_position.z)
				preview_position = final_position
		else:
			# Pour les fondations, ajuster légèrement au-dessus du sol
			final_position.y += 0.1
			preview_position = final_position
	
	# Validation
	var validation = can_place_object(object_type, final_position, current_construction_type)
	preview_valid = validation.valid
	
	# Appliquer le matériau
	if preview_valid:
		preview_object.material_override = preview_material_valid
	else:
		preview_object.material_override = preview_material_invalid
	
	# Positionner le preview
	preview_object.global_position = final_position
	preview_object.rotation_degrees.y = current_rotation
	preview_object.visible = true

func _calculate_target_position() -> Vector3:
	"""Calcule la position cible basée sur le raycast de la caméra"""
	var from = camera.global_position
	var to = from + (-camera.global_transform.basis.z) * max_build_distance
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_point = result.position
		if player.global_position.distance_to(hit_point) <= max_build_distance:
			return hit_point
	
	return Vector3.INF

func _get_foundation_height_at(horizontal_pos: Vector2) -> float:
	"""Trouve la hauteur de fondation à une position donnée"""
	var closest_height = -999.0
	var min_distance = 999.0
	
	for foundation_data in placed_foundations:
		if not foundation_data.node or not is_instance_valid(foundation_data.node):
			continue
		
		var foundation_pos = foundation_data.node.global_position
		var foundation_2d = Vector2(foundation_pos.x, foundation_pos.z)
		var distance = horizontal_pos.distance_to(foundation_2d)
		
		if distance <= foundation_size * 0.6 and distance < min_distance:
			closest_height = foundation_pos.y + 0.1
			min_distance = distance
	
	return closest_height

func _update_preview_mesh():
	"""Met à jour le mesh du preview"""
	if current_construction_type != ConstructionType.BUILDING:
		return
	
	var building_data = building_catalog.get(selected_building_type, {})
	var scene_path = building_data.get("scene_path", "")
	
	if ResourceLoader.exists(scene_path):
		var scene = load(scene_path)
		var temp_instance = scene.instantiate()
		var mesh_node = temp_instance.find_child("MeshInstance3D")
		
		if mesh_node:
			preview_object.mesh = mesh_node.mesh
			var building_size = building_data.get("size", Vector3.ONE)
			preview_object.position = Vector3(0, building_size.y * 0.5, 0)
		
		temp_instance.queue_free()
	else:
		# Mesh de fallback
		var box_mesh = BoxMesh.new()
		box_mesh.size = building_data.get("size", Vector3.ONE)
		preview_object.mesh = box_mesh

# ============================================
# INTERFACE UTILISATEUR
# ============================================

func _input(event):
	"""Gestion des entrées utilisateur"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F:
			_toggle_selection_mode()
	
	if current_build_mode == BuildMode.SELECTING:
		return
	
	if current_build_mode == BuildMode.BUILDING_STRUCTURE:
		if event.is_action_pressed("rotate_building"):
			_rotate_preview()
		
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("place_building"):
			_try_place_building()
		
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel_building"):
			_exit_build_mode()

func _toggle_selection_mode():
	"""Bascule le mode de sélection"""
	match current_build_mode:
		BuildMode.INACTIVE:
			_enter_selection_mode()
		BuildMode.SELECTING:
			_exit_build_mode()
		BuildMode.BUILDING_STRUCTURE:
			_enter_selection_mode()

func _enter_selection_mode():
	"""Entre en mode sélection"""
	current_build_mode = BuildMode.SELECTING
	selection_wheel.show_wheel()
	preview_object.visible = false

func _exit_build_mode():
	"""Sort du mode construction"""
	current_build_mode = BuildMode.INACTIVE
	preview_object.visible = false
	construction_ui.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _rotate_preview():
	"""Fait tourner le preview"""
	current_rotation += rotation_step
	if current_rotation >= 360:
		current_rotation = 0

func _try_place_building():
	"""Tente de placer un bâtiment"""
	if not preview_valid:
		print("❌ Placement impossible")
		return
	
	if place_building(selected_building_type, preview_position, current_rotation):
		print("✅ Bâtiment placé avec succès")
	else:
		print("❌ Échec du placement")

# ============================================
# CALLBACKS UI
# ============================================

func _on_building_selected(building_type: int, scene_path: String):
	"""Callback de sélection d'un bâtiment"""
	selected_building_type = building_type
	current_construction_type = ConstructionType.BUILDING
	current_build_mode = BuildMode.BUILDING_STRUCTURE
	
	_update_preview_mesh()
	construction_ui.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_wheel_closed():
	"""Callback de fermeture du menu"""
	if current_build_mode == BuildMode.SELECTING:
		_exit_build_mode()

# ============================================
# MISE À JOUR EN TEMPS RÉEL
# ============================================

func _process(_delta):
	"""Mise à jour à chaque frame"""
	if current_build_mode == BuildMode.BUILDING_STRUCTURE:
		_update_preview()
		_update_ui()

func _update_ui():
	"""Met à jour l'interface utilisateur"""
	if not info_label:
		return
	
	var text = ""
	match current_build_mode:
		BuildMode.INACTIVE:
			text = "F: Ouvrir menu de construction"
		BuildMode.SELECTING:
			text = "Sélectionnez un type de bâtiment"
		BuildMode.BUILDING_STRUCTURE:
			var building_data = building_catalog.get(selected_building_type, {})
			text = "🏗️ Construction: " + building_data.get("name", "Inconnu") + "\n"
			text += "Rotation: " + str(int(current_rotation)) + "°\n"
			
			if preview_object.visible:
				text += "Position: " + str(preview_position) + "\n"
			
			if current_snap_result.get("valid", false):
				text += "🔗 Snap: " + current_snap_result.get("face_name", "unknown") + "\n"
			
			text += "État: " + ("✅ Prêt" if preview_valid else "❌ Invalide") + "\n"
			text += "\nContrôles:\n"
			text += "  Clic: Placer\n"
			text += "  R: Rotation\n"
			text += "  F: Menu | Échap: Annuler"
	
	info_label.text = text

# ============================================
# MÉTHODES PUBLIQUES
# ============================================

func get_building_count() -> int:
	return placed_buildings.size()

func get_foundation_count() -> int:
	return placed_foundations.size()

func clear_all_buildings():
	for building in placed_buildings:
		if building.node and is_instance_valid(building.node):
			building.node.queue_free()
	placed_buildings.clear()

# Pour compatibilité temporaire avec les fondations
func has_foundation_at_position(position: Vector3, tolerance: float = 2.0) -> bool:
	return _is_on_foundation(position)

func get_placed_foundations() -> Array[Dictionary]:
	return placed_foundations
