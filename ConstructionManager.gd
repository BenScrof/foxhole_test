# ============================================
# ConstructionManager.gd - Version avec Roue de Sélection
# ============================================
# Votre système optimisé + roue circulaire pour la sélection

extends Node3D
class_name ConstructionManager

@export var foundation_size: float = 4.0
@export var max_build_distance: float = 15.0
@export var grid_snap: bool = true
@export var preview_alpha: float = 0.6

@export_group("Types de Construction")
@export var foundation_model_path: String = "res://assets/models/fondation.tscn"
@export var ramp_model_path: String = "res://assets/models/rampe_test.tscn"
@export var coin_rampe_model_path: String = "res://assets/models/coin_rampe.tscn"

# États de construction
enum BuildMode {
	INACTIVE,
	SELECTING,     # Nouveau : sélection avec roue
	BUILDING       # Mode construction actif
}

var current_build_mode: BuildMode = BuildMode.INACTIVE
var selected_foundation_type: FoundationSelectionWheel.FoundationType = FoundationSelectionWheel.FoundationType.NORMAL
var current_rotation: float = 0.0
var rotation_step: float = 90.0
var current_build_height: float = 0.0

var preview_object: MeshInstance3D
var preview_valid: bool = false
var preview_position: Vector3

var foundation_material: StandardMaterial3D
var ramp_material: StandardMaterial3D
var preview_material_valid: StandardMaterial3D
var preview_material_invalid: StandardMaterial3D

# Scènes chargées
var foundation_scene: PackedScene
var ramp_scene: PackedScene
var coin_rampe_scene: PackedScene

# Cache pour optimisation mémoire
var foundation_mesh_cache: Mesh
var ramp_mesh_cache: Mesh
var coin_rampe_mesh_cache: Mesh
var ramp_snap_cache: Vector3
var foundation_snap_cache: Dictionary

var player: Player
var camera: Camera3D
var terrain_manager: TerrainManager

var placed_foundations: Array[Dictionary] = []
var selected_face: int = 0  # 0=droite, 1=arrière, 2=gauche, 3=avant
var ramp_base_rotation: Vector3 = Vector3.ZERO

# Optimisation : réduire fréquence de mise à jour
var update_counter: int = 0
var update_frequency: int = 3  # Mise à jour tous les 3 frames

# 🎡 NOUVEAU : Roue de sélection
var selection_wheel: FoundationSelectionWheel
var construction_ui: Control
var info_label: Label

func _ready():
	add_to_group("construction_manager")
	_setup_materials()
	_setup_preview()
	
	await get_tree().process_frame
	_find_references()
	call_deferred("_setup_selection_wheel")
	
	print("🔨 Construction avec roue de sélection")

func _find_references():
	player = get_tree().get_first_node_in_group("player")
	terrain_manager = get_tree().get_first_node_in_group("world")
	
	if player:
		camera = player.get_node("Head/Camera3D")

func _setup_materials():
	foundation_material = StandardMaterial3D.new()
	foundation_material.albedo_color = Color(0.7, 0.7, 0.7)
	foundation_material.roughness = 0.6
	
	ramp_material = StandardMaterial3D.new()
	ramp_material.albedo_color = Color(0.6, 0.5, 0.4)
	ramp_material.roughness = 0.7
	
	preview_material_valid = StandardMaterial3D.new()
	preview_material_valid.albedo_color = Color(0.3, 1.0, 0.3, preview_alpha)
	preview_material_valid.flags_transparent = true
	
	preview_material_invalid = StandardMaterial3D.new()
	preview_material_invalid.albedo_color = Color(1.0, 0.3, 0.3, preview_alpha)
	preview_material_invalid.flags_transparent = true

	# Charger et mettre en cache les modèles
	_load_and_cache_models()

func _load_and_cache_models():
	# Cache fondation
	if ResourceLoader.exists(foundation_model_path):
		foundation_scene = load(foundation_model_path)
		print("✅ Modèle fondation chargé: ", foundation_model_path)
		_cache_foundation_data()
	else:
		print("⚠️ Modèle fondation non trouvé: ", foundation_model_path)
		
	# Cache rampe
	if ResourceLoader.exists(ramp_model_path):
		ramp_scene = load(ramp_model_path)
		print("✅ Modèle rampe chargé: ", ramp_model_path)
		_cache_ramp_data()
	else:
		print("⚠️ Modèle rampe non trouvé: ", ramp_model_path)
	
	# Cache coin rampe
	if ResourceLoader.exists(coin_rampe_model_path):
		coin_rampe_scene = load(coin_rampe_model_path)
		print("✅ Modèle coin rampe chargé: ", coin_rampe_model_path)
		_cache_coin_rampe_data()
	else:
		print("⚠️ Modèle coin rampe non trouvé: ", coin_rampe_model_path)

func _cache_foundation_data():
	"""Mettre en cache les données de la fondation pour éviter les instances répétées"""
	if not foundation_scene:
		return
		
	var temp_instance = foundation_scene.instantiate()
	
	# Cache mesh
	var mesh_node = temp_instance.find_child("MeshInstance3D")
	if mesh_node:
		foundation_mesh_cache = mesh_node.mesh
	
	# Cache snap points
	foundation_snap_cache = {}
	for child in temp_instance.get_children():
		if child.name.begins_with("SnapPoint_"):
			var snap_name = child.name.replace("SnapPoint_", "")
			foundation_snap_cache[snap_name] = child.position
	
	temp_instance.queue_free()
	print("📦 Cache fondation: ", foundation_snap_cache.size(), " snaps")

func _cache_ramp_data():
	"""Mettre en cache les données de la rampe"""
	if not ramp_scene:
		return
		
	var temp_instance = ramp_scene.instantiate()
	
	# Cache mesh
	var mesh_node = temp_instance.find_child("MeshInstance3D")
	if mesh_node:
		ramp_mesh_cache = mesh_node.mesh
		ramp_base_rotation = mesh_node.rotation_degrees
	
	# Cache snap point
	var snap_entry = temp_instance.find_child("SnapPoint_Entry")
	if snap_entry:
		ramp_snap_cache = snap_entry.position
	
	temp_instance.queue_free()
	print("📦 Cache rampe: snap à ", ramp_snap_cache)

func _cache_coin_rampe_data():
	"""Mettre en cache les données du coin rampe"""
	if not coin_rampe_scene:
		return
		
	var temp_instance = coin_rampe_scene.instantiate()
	
	# Cache mesh
	var mesh_node = temp_instance.find_child("MeshInstance3D")
	if mesh_node:
		coin_rampe_mesh_cache = mesh_node.mesh
	
	temp_instance.queue_free()
	print("📦 Cache coin rampe chargé")

func _setup_preview():
	preview_object = MeshInstance3D.new()
	_update_preview_mesh()
	add_child(preview_object)
	preview_object.visible = false

# 🎡 NOUVEAU : Configuration de la roue de sélection
func _setup_selection_wheel():
	"""Créer la roue de sélection"""
	print("🎡 Configuration roue de sélection...")
	
	# Créer la roue
	selection_wheel = FoundationSelectionWheel.new()
	selection_wheel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selection_wheel.z_index = 1000
	
	# Ajouter à la scène
	get_tree().root.add_child.call_deferred(selection_wheel)
	
	await get_tree().process_frame
	
	# Connecter les signaux
	selection_wheel.foundation_selected.connect(_on_foundation_selected)
	selection_wheel.wheel_closed.connect(_on_wheel_closed)
	
	# Interface d'information
	construction_ui = Control.new()
	construction_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child.call_deferred(construction_ui)
	
	await get_tree().process_frame
	
	info_label = Label.new()
	info_label.position = Vector2(20, 100)
	info_label.size = Vector2(400, 200)
	info_label.add_theme_color_override("font_color", Color.YELLOW)
	info_label.add_theme_font_size_override("font_size", 16)
	construction_ui.add_child(info_label)
	
	construction_ui.visible = false
	
	print("✅ Roue de sélection configurée")

func _update_preview_mesh():
	preview_object.transform = Transform3D.IDENTITY
	
	match selected_foundation_type:
		FoundationSelectionWheel.FoundationType.NORMAL:
			if foundation_mesh_cache:
				preview_object.mesh = foundation_mesh_cache
			else:
				var box_mesh = BoxMesh.new()
				box_mesh.size = Vector3(foundation_size, 0.3, foundation_size)
				preview_object.mesh = box_mesh
		
		FoundationSelectionWheel.FoundationType.RAMPE:
			if ramp_mesh_cache:
				preview_object.mesh = ramp_mesh_cache
			else:
				var prism_mesh = PrismMesh.new()
				prism_mesh.left_to_right = 1.0
				prism_mesh.size = Vector3(2, 0.2, 4)
				preview_object.mesh = prism_mesh
		
		FoundationSelectionWheel.FoundationType.COIN_RAMPE:
			if coin_rampe_mesh_cache:
				preview_object.mesh = coin_rampe_mesh_cache
			else:
				var box_mesh = BoxMesh.new()
				box_mesh.size = Vector3(foundation_size, 0.3, foundation_size)
				preview_object.mesh = box_mesh

func _input(event):
	# 🎡 F pour ouvrir la roue de sélection
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		_toggle_selection_mode()
	
	# TAB pour changer de face (seulement en mode rampe)
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB and selected_foundation_type == FoundationSelectionWheel.FoundationType.RAMPE and current_build_mode == BuildMode.BUILDING:
		_cycle_face()
		get_viewport().set_input_as_handled()
	
	# Hauteur en mode construction
	if current_build_mode == BuildMode.BUILDING:
		if event.is_action_pressed("height_up"):
			adjust_build_height(0.2)
		elif event.is_action_pressed("height_down"):
			adjust_build_height(-0.2)
	
	# Rotation en mode construction
	if event.is_action_pressed("rotate_building") and current_build_mode == BuildMode.BUILDING:
		rotate_preview()
	
	# Placement
	if current_build_mode == BuildMode.BUILDING and (event.is_action_pressed("ui_accept") or event.is_action_pressed("place_building")):
		_try_place_structure()
	
	# Annulation
	if current_build_mode == BuildMode.BUILDING and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel_building")):
		_exit_build_mode()

# 🎡 NOUVEAUX : Gestion de la roue de sélection
func _toggle_selection_mode():
	"""Basculer entre les modes"""
	match current_build_mode:
		BuildMode.INACTIVE:
			_enter_selection_mode()
		BuildMode.SELECTING:
			_exit_build_mode()
		BuildMode.BUILDING:
			_enter_selection_mode()

func _enter_selection_mode():
	"""Entrer en mode sélection (ouvrir la roue)"""
	current_build_mode = BuildMode.SELECTING
	selection_wheel.show_wheel()
	
	# Cacher la prévisualisation
	if preview_object:
		preview_object.visible = false
	
	print("🎡 Mode sélection activé")

func _exit_build_mode():
	"""Sortir complètement du mode construction"""
	current_build_mode = BuildMode.INACTIVE
	
	# Cacher tout
	if preview_object:
		preview_object.visible = false
	if construction_ui:
		construction_ui.visible = false
	
	# Restaurer le mode souris
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	print("🚶 Mode déplacement")

func _on_foundation_selected(foundation_type: FoundationSelectionWheel.FoundationType, scene_path: String):
	"""Callback : type sélectionné dans la roue"""
	selected_foundation_type = foundation_type
	current_build_mode = BuildMode.BUILDING
	
	# Mettre à jour le mesh de prévisualisation
	_update_preview_mesh()
	
	# Afficher l'interface de construction
	if construction_ui:
		construction_ui.visible = true
	
	# Restaurer le mode FPS
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	print("🏗️ Mode construction : ", _get_foundation_type_name(foundation_type))

func _on_wheel_closed():
	"""Callback : roue fermée sans sélection"""
	if current_build_mode == BuildMode.SELECTING:
		_exit_build_mode()

func _get_foundation_type_name(type: FoundationSelectionWheel.FoundationType) -> String:
	"""Obtenir le nom d'un type"""
	match type:
		FoundationSelectionWheel.FoundationType.NORMAL:
			return "Fondation"
		FoundationSelectionWheel.FoundationType.RAMPE:
			return "Rampe"
		FoundationSelectionWheel.FoundationType.COIN_RAMPE:
			return "Coin Rampe"
		_:
			return "Inconnu"

func _cycle_face():
	selected_face = (selected_face + 1) % 4
	var face_names = ["Nord (Droite)", "Est (Arrière)", "Sud (Gauche)", "Ouest (Avant)"]
	print("🔄 Face: ", face_names[selected_face])

func adjust_build_height(delta: float):
	current_build_height += delta
	current_build_height = clamp(current_build_height, -5.0, 10.0)
	print("🏗️ Hauteur: ", snappedf(current_build_height, 0.1), "m")

func rotate_preview():
	current_rotation += rotation_step
	if current_rotation >= 360:
		current_rotation = 0

func _process(_delta):
	if current_build_mode == BuildMode.BUILDING and preview_object.visible:
		update_counter += 1
		if update_counter >= update_frequency:
			update_counter = 0
			_update_preview()
			_update_construction_ui()

func _update_construction_ui():
	"""Mettre à jour l'interface de construction"""
	if not info_label:
		return
	
	var text = ""
	
	match current_build_mode:
		BuildMode.INACTIVE:
			text = "F: Ouvrir sélection"
		
		BuildMode.SELECTING:
			text = "Sélectionnez un type de fondation"
		
		BuildMode.BUILDING:
			text = "🏗️ Mode Construction\n"
			text += "Type: " + _get_foundation_type_name(selected_foundation_type) + "\n"
			text += "Rotation: " + str(int(current_rotation)) + "°\n"
			text += "Hauteur: " + str(snappedf(current_build_height, 0.1)) + "m\n"
			
			if selected_foundation_type == FoundationSelectionWheel.FoundationType.RAMPE:
				var face_names = ["Nord", "Est", "Sud", "Ouest"]
				text += "Face: " + face_names[selected_face] + "\n"
			
			text += "\nContrôles:\n"
			text += "  Clic gauche: Placer\n"
			text += "  R: Rotation\n"
			if selected_foundation_type == FoundationSelectionWheel.FoundationType.RAMPE:
				text += "  TAB: Changer face\n"
			text += "  F: Changer type\n"
			text += "  Échap: Annuler\n\n"
			text += "Placement: " + ("✅ Valide" if preview_valid else "❌ Invalide")
	
	info_label.text = text

func _update_preview():
	if not player or not camera:
		return
	
	match selected_foundation_type:
		FoundationSelectionWheel.FoundationType.NORMAL:
			_update_foundation_preview()
		FoundationSelectionWheel.FoundationType.RAMPE:
			_update_ramp_preview()
		FoundationSelectionWheel.FoundationType.COIN_RAMPE:
			_update_coin_rampe_preview()

func _update_foundation_preview():
	var target_position = _calculate_build_position()
	
	if target_position != Vector3.INF:
		if grid_snap:
			target_position = _snap_to_grid(target_position)
		
		target_position.y = current_build_height
		preview_position = target_position
		
		preview_object.global_position = target_position
		preview_object.rotation_degrees = Vector3(0, current_rotation, 0)
		
		preview_valid = _is_position_valid(target_position)
		
		if preview_valid:
			preview_object.material_override = preview_material_valid
		else:
			preview_object.material_override = preview_material_invalid
		
		preview_object.visible = true
	else:
		preview_object.visible = false

func _update_ramp_preview():
	var face_data = _get_face_placement_data()
	
	if face_data.has("foundation"):
		var snap_data = _calculate_snap_position(face_data.foundation)
		
		if snap_data.has("position"):
			preview_position = snap_data.position
			
			var final_rotation = ramp_base_rotation + snap_data.rotation
			
			preview_object.global_position = snap_data.position
			preview_object.rotation_degrees = final_rotation
			
			preview_valid = true
			preview_object.material_override = preview_material_valid
		else:
			preview_valid = false
			preview_object.material_override = preview_material_invalid
		
		preview_object.visible = true
	else:
		var target_position = _calculate_build_position()
		
		if target_position != Vector3.INF:
			preview_position = target_position
			
			var final_rotation = ramp_base_rotation + _get_face_rotation(selected_face)
			
			preview_object.global_position = target_position
			preview_object.rotation_degrees = final_rotation
			
			preview_valid = false
			preview_object.material_override = preview_material_invalid
			preview_object.visible = true
		else:
			preview_object.visible = false

func _update_coin_rampe_preview():
	# Pour l'instant, même logique que la fondation
	_update_foundation_preview()

func _calculate_build_position() -> Vector3:
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

func _get_face_placement_data() -> Dictionary:
	var from = camera.global_position
	var to = from + (-camera.global_transform.basis.z) * max_build_distance
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player]
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider and _is_foundation(result.collider):
		return {
			"position": result.position,
			"normal": result.normal,
			"foundation": result.collider
		}
	
	return {}

func _is_foundation(object: Node) -> bool:
	if not object:
		return false
	
	var current = object
	while current:
		if current.name.begins_with("Foundation") or current.name.begins_with("Fondation"):
			return true
		current = current.get_parent()
		if current == get_tree().root:
			break
	
	return false

func _snap_to_grid(pos: Vector3) -> Vector3:
	var snapped_x = round(pos.x / foundation_size) * foundation_size
	var snapped_z = round(pos.z / foundation_size) * foundation_size
	return Vector3(snapped_x, pos.y, snapped_z)

func _is_position_valid(pos: Vector3) -> bool:
	if player and player.global_position.distance_to(pos) > max_build_distance:
		return false
	return true

func _try_place_structure():
	if not preview_valid:
		print("❌ Placement impossible")
		return
	
	match selected_foundation_type:
		FoundationSelectionWheel.FoundationType.NORMAL:
			_place_foundation_at(preview_position)
		FoundationSelectionWheel.FoundationType.RAMPE:
			_place_ramp_at(preview_position)
		FoundationSelectionWheel.FoundationType.COIN_RAMPE:
			_place_coin_rampe_at(preview_position)

func _place_foundation_at(pos: Vector3):
	var grid_2d = Vector2i(int(pos.x / foundation_size), int(pos.z / foundation_size))
	
	var foundation = _create_foundation_from_scene(pos)
	
	var foundation_data = {
		"node": foundation,
		"height": pos.y,
		"grid_pos": grid_2d
	}
	
	placed_foundations.append(foundation_data)
	
	print("✅ Fondation placée! Total: ", placed_foundations.size())

func _create_foundation_from_scene(pos: Vector3) -> Node3D:
	if not foundation_scene:
		return null
	
	var foundation = foundation_scene.instantiate()
	foundation.name = "Foundation_" + str(placed_foundations.size())
	foundation.add_to_group("foundations")  # Important pour les snaps
	
	var collision_node = foundation.find_child("CollisionShape3D")
	if collision_node:
		var collision_parent = collision_node.get_parent()
		if not collision_parent is StaticBody3D:
			var static_body = StaticBody3D.new()
			static_body.name = "StaticBody3D"
			foundation.add_child(static_body)
			
			var mesh_node = foundation.find_child("MeshInstance3D")
			if mesh_node:
				mesh_node.reparent(static_body)
			collision_node.reparent(static_body)
	
	get_tree().root.add_child(foundation)
	foundation.global_position = pos
	foundation.rotation_degrees.y = current_rotation
	
	return foundation

func _place_ramp_at(pos: Vector3):
	if not ramp_scene:
		print("❌ Modèle rampe non disponible")
		return
	
	var ramp_instance = ramp_scene.instantiate()
	ramp_instance.name = "Ramp_" + str(placed_foundations.size())
	ramp_instance.add_to_group("foundations")  # Important pour les snaps
	
	get_tree().root.add_child(ramp_instance)
	ramp_instance.global_position = pos
	ramp_instance.rotation_degrees = preview_object.rotation_degrees
	
	print("✅ Rampe placée avec snap!")

func _place_coin_rampe_at(pos: Vector3):
	if not coin_rampe_scene:
		print("❌ Modèle coin rampe non disponible")
		return
	
	var coin_rampe_instance = coin_rampe_scene.instantiate()
	coin_rampe_instance.name = "CoinRampe_" + str(placed_foundations.size())
	coin_rampe_instance.add_to_group("foundations")  # Important pour les snaps
	
	get_tree().root.add_child(coin_rampe_instance)
	coin_rampe_instance.global_position = pos
	coin_rampe_instance.rotation_degrees.y = current_rotation
	
	print("✅ Coin rampe placé!")

func _get_snap_points(object: Node3D) -> Dictionary:
	var snap_points = {}
	
	for child in object.get_children():
		if child.name.begins_with("SnapPoint_"):
			var snap_name = child.name.replace("SnapPoint_", "")
			snap_points[snap_name] = child.global_position
	
	return snap_points

func _calculate_snap_position(foundation: Node3D) -> Dictionary:
	var foundation_snaps = _get_snap_points(foundation)
	
	var face_to_snap = {
		0: "Side_North",
		1: "Side_East", 
		2: "Side_South",
		3: "Side_West"
	}
	
	var target_snap = face_to_snap.get(selected_face, "Side_North")
	
	if foundation_snaps.has(target_snap):
		var foundation_snap_pos = foundation_snaps[target_snap]
		var face_rotation = _get_face_rotation(selected_face)
		
		var ramp_snap_offset = _get_ramp_entry_offset()
		
		var total_rotation = ramp_base_rotation.y + face_rotation.y
		var rotated_offset = ramp_snap_offset.rotated(Vector3.UP, deg_to_rad(total_rotation))
		
		var final_position = foundation_snap_pos - rotated_offset
		var final_rotation = ramp_base_rotation + face_rotation
		
		return {
			"position": final_position,
			"rotation": final_rotation
		}
	
	return {}

func _get_ramp_entry_offset() -> Vector3:
	return ramp_snap_cache

func _get_face_rotation(face_index: int) -> Vector3:
	match face_index:
		0: return Vector3(0, -180, 0)   # Droite (Nord)
		1: return Vector3(0, 90, 0)     # Arrière (Est)
		2: return Vector3(0, 0, 0)      # Gauche (Sud)
		3: return Vector3(0, -90, 0)    # Avant (Ouest)
		_: return Vector3.ZERO

func get_foundation_count() -> int:
	return placed_foundations.size()

func clear_all_foundations():
	for foundation_data in placed_foundations:
		if foundation_data.node and is_instance_valid(foundation_data.node):
			foundation_data.node.queue_free()
	placed_foundations.clear()
	current_build_height = 0.0
	
	print("🧹 Nettoyage mémoire effectué")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		clear_all_foundations()
