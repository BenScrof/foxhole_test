# ============================================
# ConstructionManager.gd - Version WFC avec Système de Règles
# ============================================

extends Node3D
class_name ConstructionManager

@export var foundation_size: float = 4.0
@export var max_build_distance: float = 15.0
@export var grid_snap: bool = true
@export var preview_alpha: float = 0.6

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

var current_build_mode: BuildMode = BuildMode.INACTIVE
var current_construction_type: ConstructionType = ConstructionType.FOUNDATION

# Variables pour fondations
var selected_foundation_type: FoundationSelectionWheel.FoundationType = FoundationSelectionWheel.FoundationType.NORMAL
var current_rotation: float = 0.0
var rotation_step: float = 90.0
var current_build_height: float = 0.0

# Variables pour bâtiments WFC
var selected_building_type: BuildingSystem.BuildingType = BuildingSystem.BuildingType.MUR_DROIT

var preview_object: MeshInstance3D
var preview_valid: bool = false
var preview_position: Vector3

var foundation_material: StandardMaterial3D
var preview_material_valid: StandardMaterial3D
var preview_material_invalid: StandardMaterial3D

# Scènes fondations
var foundation_scene: PackedScene
var ramp_scene: PackedScene
var coin_rampe_scene: PackedScene

# Cache fondations
var foundation_mesh_cache: Mesh
var ramp_mesh_cache: Mesh
var coin_rampe_mesh_cache: Mesh
var ramp_snap_cache: Vector3
var foundation_snap_cache: Dictionary
var ramp_base_rotation: Vector3 = Vector3.ZERO

var player: Player
var camera: Camera3D
var terrain_manager: TerrainManager
var building_system: BuildingSystem

var placed_foundations: Array[Dictionary] = []
var selected_face: int = 0

var update_counter: int = 0
var update_frequency: int = 3

# UI
var selection_wheel: FoundationSelectionWheel
var construction_ui: Control
var info_label: Label

func _ready():
	add_to_group("construction_manager")
	_setup_materials()
	_setup_preview()
	_setup_building_system()
	
	await get_tree().process_frame
	_find_references()
	call_deferred("_setup_selection_wheel")

func _setup_building_system():
	building_system = BuildingSystem.new()
	add_child(building_system)

func _find_references():
	player = get_tree().get_first_node_in_group("player")
	terrain_manager = get_tree().get_first_node_in_group("world")
	
	if player:
		camera = player.get_node("Head/Camera3D")

func _setup_materials():
	foundation_material = StandardMaterial3D.new()
	foundation_material.albedo_color = Color(0.7, 0.7, 0.7)
	foundation_material.roughness = 0.6
	
	preview_material_valid = StandardMaterial3D.new()
	preview_material_valid.albedo_color = Color(0.3, 1.0, 0.3, preview_alpha)
	preview_material_valid.flags_transparent = true
	
	preview_material_invalid = StandardMaterial3D.new()
	preview_material_invalid.albedo_color = Color(1.0, 0.3, 0.3, preview_alpha)
	preview_material_invalid.flags_transparent = true

	_load_and_cache_models()

func _load_and_cache_models():
	var scenes = {
		"fondation": "res://assets/models/fondation.tscn",
		"rampe": "res://assets/models/rampe_test.tscn", 
		"coin_rampe": "res://assets/models/coin_rampe.tscn"
	}
	
	for key in scenes:
		var path = scenes[key]
		if ResourceLoader.exists(path):
			match key:
				"fondation":
					foundation_scene = load(path)
					_cache_foundation_data()
				"rampe":
					ramp_scene = load(path)
					_cache_ramp_data()
				"coin_rampe":
					coin_rampe_scene = load(path)
					_cache_coin_rampe_data()

func _cache_foundation_data():
	if not foundation_scene:
		return
		
	var temp_instance = foundation_scene.instantiate()
	var mesh_node = temp_instance.find_child("MeshInstance3D")
	if mesh_node:
		foundation_mesh_cache = mesh_node.mesh
	
	foundation_snap_cache = {}
	for child in temp_instance.get_children():
		if child.name.begins_with("SnapPoint_"):
			var snap_name = child.name.replace("SnapPoint_", "")
			foundation_snap_cache[snap_name] = child.position
	
	temp_instance.queue_free()

func _cache_ramp_data():
	if not ramp_scene:
		return
		
	var temp_instance = ramp_scene.instantiate()
	var mesh_node = temp_instance.find_child("MeshInstance3D")
	if mesh_node:
		ramp_mesh_cache = mesh_node.mesh
		ramp_base_rotation = mesh_node.rotation_degrees
	
	var snap_entry = temp_instance.find_child("SnapPoint_Entry")
	if snap_entry:
		ramp_snap_cache = snap_entry.position
	
	temp_instance.queue_free()

func _cache_coin_rampe_data():
	if not coin_rampe_scene:
		return
		
	var temp_instance = coin_rampe_scene.instantiate()
	var mesh_node = temp_instance.find_child("MeshInstance3D")
	if mesh_node:
		coin_rampe_mesh_cache = mesh_node.mesh
	
	temp_instance.queue_free()

func _setup_preview():
	preview_object = MeshInstance3D.new()
	_update_preview_mesh()
	add_child(preview_object)
	preview_object.visible = false

func _setup_selection_wheel():
	selection_wheel = FoundationSelectionWheel.new()
	selection_wheel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selection_wheel.z_index = 1000
	
	get_tree().root.add_child.call_deferred(selection_wheel)
	await get_tree().process_frame
	
	# Connecter signaux
	selection_wheel.foundation_selected.connect(_on_foundation_selected)
	selection_wheel.building_selected.connect(_on_building_selected)
	selection_wheel.wheel_closed.connect(_on_wheel_closed)
	
	# UI d'info
	construction_ui = Control.new()
	construction_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child.call_deferred(construction_ui)
	await get_tree().process_frame
	
	info_label = Label.new()
	info_label.position = Vector2(20, 100)
	info_label.size = Vector2(450, 300)
	info_label.add_theme_color_override("font_color", Color.YELLOW)
	info_label.add_theme_font_size_override("font_size", 16)
	construction_ui.add_child(info_label)
	construction_ui.visible = false

func _update_preview_mesh():
	preview_object.transform = Transform3D.IDENTITY
	
	match current_construction_type:
		ConstructionType.FOUNDATION:
			match selected_foundation_type:
				FoundationSelectionWheel.FoundationType.NORMAL:
					preview_object.mesh = foundation_mesh_cache if foundation_mesh_cache else _create_fallback_box()
				FoundationSelectionWheel.FoundationType.RAMPE:
					preview_object.mesh = ramp_mesh_cache if ramp_mesh_cache else _create_fallback_prism()
				FoundationSelectionWheel.FoundationType.COIN_RAMPE:
					preview_object.mesh = coin_rampe_mesh_cache if coin_rampe_mesh_cache else _create_fallback_box()
		
		ConstructionType.BUILDING:
			_load_building_preview_mesh()

func _load_building_preview_mesh():
	var building_data = building_system.building_data.get(selected_building_type, {})
	var scene_path = building_data.get("scene_path", "")
	
	if ResourceLoader.exists(scene_path):
		var scene = load(scene_path)
		var temp_instance = scene.instantiate()
		var mesh_node = temp_instance.find_child("MeshInstance3D")
		if mesh_node:
			preview_object.mesh = mesh_node.mesh
		temp_instance.queue_free()
	else:
		preview_object.mesh = _create_fallback_box()

func _create_fallback_box() -> BoxMesh:
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(foundation_size, 0.3, foundation_size)
	return box_mesh

func _create_fallback_prism() -> PrismMesh:
	var prism_mesh = PrismMesh.new()
	prism_mesh.left_to_right = 1.0
	prism_mesh.size = Vector3(2, 0.2, 4)
	return prism_mesh

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		_toggle_selection_mode()
	
	if current_build_mode == BuildMode.SELECTING:
		return
	
	if current_build_mode in [BuildMode.BUILDING_FOUNDATION, BuildMode.BUILDING_STRUCTURE]:
		if event is InputEventKey and event.pressed and event.keycode == KEY_TAB and selected_foundation_type == FoundationSelectionWheel.FoundationType.RAMPE and current_construction_type == ConstructionType.FOUNDATION:
			_cycle_face()
			get_viewport().set_input_as_handled()
		
		if event.is_action_pressed("height_up"):
			adjust_build_height(0.2)
		elif event.is_action_pressed("height_down"):
			adjust_build_height(-0.2)
		
		if event.is_action_pressed("rotate_building"):
			rotate_preview()
		
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("place_building"):
			_try_place_structure()
		
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel_building"):
			_exit_build_mode()

func _toggle_selection_mode():
	match current_build_mode:
		BuildMode.INACTIVE:
			_enter_selection_mode()
		BuildMode.SELECTING:
			_exit_build_mode()
		BuildMode.BUILDING_FOUNDATION, BuildMode.BUILDING_STRUCTURE:
			_enter_selection_mode()

func _enter_selection_mode():
	current_build_mode = BuildMode.SELECTING
	selection_wheel.show_wheel()
	if preview_object:
		preview_object.visible = false

func _exit_build_mode():
	current_build_mode = BuildMode.INACTIVE
	current_construction_type = ConstructionType.FOUNDATION
	if preview_object:
		preview_object.visible = false
	if construction_ui:
		construction_ui.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Callbacks pour sélection
func _on_foundation_selected(foundation_type: FoundationSelectionWheel.FoundationType, scene_path: String):
	current_construction_type = ConstructionType.FOUNDATION
	selected_foundation_type = foundation_type
	current_build_mode = BuildMode.BUILDING_FOUNDATION
	
	_update_preview_mesh()
	
	if construction_ui:
		construction_ui.visible = true
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_building_selected(building_type: BuildingSystem.BuildingType, scene_path: String):
	current_construction_type = ConstructionType.BUILDING
	selected_building_type = building_type
	current_build_mode = BuildMode.BUILDING_STRUCTURE
	
	_update_preview_mesh()
	
	if construction_ui:
		construction_ui.visible = true
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_wheel_closed():
	if current_build_mode == BuildMode.SELECTING:
		_exit_build_mode()

func _get_foundation_type_name(type: FoundationSelectionWheel.FoundationType) -> String:
	match type:
		FoundationSelectionWheel.FoundationType.NORMAL:
			return "Fondation"
		FoundationSelectionWheel.FoundationType.RAMPE:
			return "Rampe"
		FoundationSelectionWheel.FoundationType.COIN_RAMPE:
			return "Coin Rampe"
		_:
			return "Inconnu"

func _get_building_type_name(type: BuildingSystem.BuildingType) -> String:
	var building_data = building_system.building_data.get(type, {})
	return building_data.get("name", "Inconnu")

func _cycle_face():
	selected_face = (selected_face + 1) % 4

func adjust_build_height(delta: float):
	current_build_height += delta
	current_build_height = clamp(current_build_height, -5.0, 10.0)

func rotate_preview():
	current_rotation += rotation_step
	if current_rotation >= 360:
		current_rotation = 0

func _process(_delta):
	if current_build_mode in [BuildMode.BUILDING_FOUNDATION, BuildMode.BUILDING_STRUCTURE]:
		update_counter += 1
		if update_counter >= update_frequency:
			update_counter = 0
			_update_preview()
			_update_construction_ui()

func _update_construction_ui():
	if not info_label:
		return
	
	var text = ""
	match current_build_mode:
		BuildMode.INACTIVE:
			text = "F: Ouvrir sélection"
		BuildMode.SELECTING:
			text = "Sélectionnez fondation ou bâtiment"
		BuildMode.BUILDING_FOUNDATION:
			text = "🏗️ Mode Fondation\n"
			text += "Type: " + _get_foundation_type_name(selected_foundation_type) + "\n"
			text += "Rotation: " + str(int(current_rotation)) + "°\n"
			text += "Hauteur: " + str(snappedf(current_build_height, 0.1)) + "m\n"
			
			if selected_foundation_type == FoundationSelectionWheel.FoundationType.RAMPE:
				var face_names = ["Nord", "Est", "Sud", "Ouest"]
				text += "Face: " + face_names[selected_face] + "\n"
		
		BuildMode.BUILDING_STRUCTURE:
			text = "🏠 Mode Bâtiment WFC\n"
			text += "Type: " + _get_building_type_name(selected_building_type) + "\n"
			text += "Rotation: " + str(int(current_rotation)) + "°\n"
			
			# Afficher validation WFC
			var validation = building_system.can_place_building(selected_building_type, preview_position, current_rotation)
			if validation.snap_data.has("snap_name"):
				text += "🔗 Snap WFC: " + validation.snap_data.snap_name + "\n"
			
			if not validation.valid:
				text += "❌ " + validation.reason + "\n"
	
	if current_build_mode in [BuildMode.BUILDING_FOUNDATION, BuildMode.BUILDING_STRUCTURE]:
		text += "\nContrôles:\n"
		text += "  Clic: Placer | R: Rotation\n"
		if current_construction_type == ConstructionType.FOUNDATION and selected_foundation_type == FoundationSelectionWheel.FoundationType.RAMPE:
			text += "  TAB: Changer face\n"
		text += "  F: Changer type | Échap: Annuler\n"
		text += "Placement: " + ("✅ Valide" if preview_valid else "❌ Invalide")
	
	info_label.text = text

func _update_preview():
	if not player or not camera:
		return
	
	match current_construction_type:
		ConstructionType.FOUNDATION:
			match selected_foundation_type:
				FoundationSelectionWheel.FoundationType.NORMAL:
					_update_foundation_preview()
				FoundationSelectionWheel.FoundationType.RAMPE:
					_update_ramp_preview()
				FoundationSelectionWheel.FoundationType.COIN_RAMPE:
					_update_foundation_preview()
		
		ConstructionType.BUILDING:
			_update_building_preview_wfc()

func _update_building_preview_wfc():
	"""Mise à jour preview avec validation WFC complète"""
	var target_position = _calculate_build_position()
	
	if target_position != Vector3.INF:
		preview_position = target_position
		
		# Validation WFC complète
		var validation = building_system.can_place_building(selected_building_type, target_position, current_rotation)
		
		# Utiliser position de snap si disponible
		if validation.snap_data.has("position"):
			target_position = validation.snap_data.position
			preview_position = target_position
		
		preview_object.global_position = target_position
		preview_object.rotation_degrees = Vector3(0, current_rotation, 0)
		
		preview_valid = validation.valid
		preview_object.material_override = preview_material_valid if preview_valid else preview_material_invalid
		preview_object.visible = true
		
		# Debug WFC
		if not validation.valid:
			print("🚫 WFC: ", validation.reason)
	else:
		preview_object.visible = false

func _update_foundation_preview():
	var target_position = _calculate_build_position()
	
	if target_position != Vector3.INF:
		if grid_snap:
			target_position = _snap_to_grid(target_position)
		
		var snap_result = _find_nearest_snap_point(target_position)
		if snap_result.has("position"):
			target_position = snap_result.position
			preview_position = target_position
			preview_object.material_override = preview_material_valid
			preview_valid = true
		else:
			target_position.y += current_build_height
			preview_position = target_position
			preview_valid = _is_position_valid(target_position)
			preview_object.material_override = preview_material_valid if preview_valid else preview_material_invalid
		
		preview_object.global_position = target_position
		preview_object.rotation_degrees = Vector3(0, current_rotation, 0)
		preview_object.visible = true
	else:
		preview_object.visible = false

func _update_ramp_preview():
	_update_foundation_preview()

func _try_place_structure():
	if not preview_valid:
		return
	
	match current_construction_type:
		ConstructionType.FOUNDATION:
			_place_foundation()
		ConstructionType.BUILDING:
			_place_building_wfc()

func _place_foundation():
	var scene_to_use = _get_scene_for_type(selected_foundation_type)
	if not scene_to_use:
		return
	
	var foundation = scene_to_use.instantiate()
	foundation.name = _get_foundation_type_name(selected_foundation_type) + "_" + str(placed_foundations.size())
	foundation.add_to_group("foundations")
	
	get_tree().root.add_child(foundation)
	foundation.global_position = preview_position
	foundation.rotation_degrees = preview_object.rotation_degrees
	
	placed_foundations.append({
		"node": foundation,
		"height": preview_position.y,
		"grid_pos": Vector2i(int(preview_position.x / foundation_size), int(preview_position.z / foundation_size))
	})

func _place_building_wfc():
	"""Placement avec système WFC"""
	building_system.place_building(selected_building_type, preview_position, current_rotation)

func _get_scene_for_type(type: FoundationSelectionWheel.FoundationType) -> PackedScene:
	match type:
		FoundationSelectionWheel.FoundationType.NORMAL:
			return foundation_scene
		FoundationSelectionWheel.FoundationType.RAMPE:
			return ramp_scene
		FoundationSelectionWheel.FoundationType.COIN_RAMPE:
			return coin_rampe_scene
		_:
			return null

# Fonctions utilitaires
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

func _find_nearest_snap_point(target_pos: Vector3) -> Dictionary:
	var snap_radius = foundation_size * 1.5
	var closest_snap = {}
	var min_distance = snap_radius
	
	for foundation_data in placed_foundations:
		if not foundation_data.node or not is_instance_valid(foundation_data.node):
			continue
		
		var foundation = foundation_data.node
		var snap_points = _get_snap_points(foundation)
		
		for snap_name in snap_points:
			var snap_pos = snap_points[snap_name]
			var distance = target_pos.distance_to(snap_pos)
			
			if distance < min_distance:
				var aligned_pos = target_pos
				aligned_pos.y = snap_pos.y
				
				if _is_valid_snap_position(aligned_pos, snap_pos):
					min_distance = distance
					closest_snap = {
						"position": aligned_pos,
						"snap_point": snap_pos,
						"foundation": foundation,
						"snap_name": snap_name
					}
	
	return closest_snap

func _get_snap_points(object: Node3D) -> Dictionary:
	var snap_points = {}
	for child in object.get_children():
		if child.name.begins_with("SnapPoint_"):
			var snap_name = child.name.replace("SnapPoint_", "")
			snap_points[snap_name] = child.global_position
	return snap_points

func _is_valid_snap_position(pos: Vector3, snap_point: Vector3) -> bool:
	if player and player.global_position.distance_to(pos) > max_build_distance:
		return false
	
	for foundation_data in placed_foundations:
		if foundation_data.node and is_instance_valid(foundation_data.node):
			var existing_pos = foundation_data.node.global_position
			if pos.distance_to(existing_pos) < foundation_size * 0.8:
				return false
	
	return true

func _snap_to_grid(pos: Vector3) -> Vector3:
	var snapped_x = round(pos.x / foundation_size) * foundation_size
	var snapped_z = round(pos.z / foundation_size) * foundation_size
	return Vector3(snapped_x, pos.y, snapped_z)

func _is_position_valid(pos: Vector3) -> bool:
	return player and player.global_position.distance_to(pos) <= max_build_distance

func get_foundation_count() -> int:
	return placed_foundations.size()

func get_building_count() -> int:
	return building_system.get_building_count() if building_system else 0

func clear_all_foundations():
	for foundation_data in placed_foundations:
		if foundation_data.node and is_instance_valid(foundation_data.node):
			foundation_data.node.queue_free()
	placed_foundations.clear()
	current_build_height = 0.0

func clear_all_buildings():
	if building_system:
		building_system.clear_all_buildings()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		clear_all_foundations()
		clear_all_buildings()
