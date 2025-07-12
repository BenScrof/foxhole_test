# ============================================
# ConstructionManager.gd - Version Optimisée Mémoire
# ============================================

extends Node3D
class_name ConstructionManager

@export var foundation_size: float = 4.0
@export var max_build_distance: float = 15.0
@export var grid_snap: bool = true
@export var preview_alpha: float = 0.6

@export_group("Types de Construction")
@export var build_mode: String = "foundation"  # "foundation", "ramp"
@export var foundation_model_path: String = "res://assets/models/fondation.tscn"
@export var ramp_model_path: String = "res://assets/models/rampe_test.tscn"

var is_building: bool = false
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

var foundation_scene: PackedScene
var ramp_scene: PackedScene

# Cache pour optimisation mémoire
var foundation_mesh_cache: Mesh
var ramp_mesh_cache: Mesh
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

func _ready():
	add_to_group("construction_manager")
	_setup_materials()
	_setup_preview()
	
	await get_tree().process_frame
	_find_references()
	
	print("🔨 Construction avec optimisations mémoire")

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

func _setup_preview():
	preview_object = MeshInstance3D.new()
	_update_preview_mesh()
	add_child(preview_object)
	preview_object.visible = false

func _update_preview_mesh():
	preview_object.transform = Transform3D.IDENTITY
	
	match build_mode:
		"foundation":
			if foundation_mesh_cache:
				preview_object.mesh = foundation_mesh_cache
			else:
				var box_mesh = BoxMesh.new()
				box_mesh.size = Vector3(foundation_size, 0.3, foundation_size)
				preview_object.mesh = box_mesh
		"ramp":
			if ramp_mesh_cache:
				preview_object.mesh = ramp_mesh_cache
			else:
				var prism_mesh = PrismMesh.new()
				prism_mesh.left_to_right = 1.0
				prism_mesh.size = Vector3(2, 0.2, 4)
				preview_object.mesh = prism_mesh

func _input(event):
	if event.is_action_pressed("build_mode"):
		toggle_build_mode()
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		_cycle_build_mode()
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB and build_mode == "ramp":
		_cycle_face()
		get_viewport().set_input_as_handled()
	
	if is_building:
		if event.is_action_pressed("height_up"):
			adjust_build_height(0.2)
		elif event.is_action_pressed("height_down"):
			adjust_build_height(-0.2)
	
	if event.is_action_pressed("rotate_building") and is_building:
		rotate_preview()
	
	if is_building and (event.is_action_pressed("ui_accept") or event.is_action_pressed("place_building")):
		_try_place_structure()
	
	if is_building and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel_building")):
		toggle_build_mode()

func _cycle_build_mode():
	match build_mode:
		"foundation":
			build_mode = "ramp"
			selected_face = 0
			print("🏗️ Mode: Rampe (Tab pour changer face)")
		"ramp":
			build_mode = "foundation"
			print("🏗️ Mode: Fondation")
	
	_update_preview_mesh()
	
	if is_building:
		preview_object.visible = true

func _cycle_face():
	selected_face = (selected_face + 1) % 4
	var face_names = ["Nord (Droite)", "Est (Arrière)", "Sud (Gauche)", "Ouest (Avant)"]
	print("🔄 Face: ", face_names[selected_face])

func adjust_build_height(delta: float):
	current_build_height += delta
	current_build_height = clamp(current_build_height, -5.0, 10.0)
	print("🏗️ Hauteur: ", snappedf(current_build_height, 0.1), "m")

func toggle_build_mode():
	is_building = !is_building
	current_rotation = 0.0
	
	if is_building:
		print("🔨 Mode construction")
		_update_preview_mesh()
		preview_object.visible = true
	else:
		preview_object.visible = false
		print("🚶 Mode déplacement")

func rotate_preview():
	current_rotation += rotation_step
	if current_rotation >= 360:
		current_rotation = 0

func _process(_delta):
	if is_building and preview_object.visible:
		update_counter += 1
		if update_counter >= update_frequency:
			update_counter = 0
			_update_preview()

func _update_preview():
	if not player or not camera:
		return
	
	if build_mode == "foundation":
		_update_foundation_preview()
	elif build_mode == "ramp":
		_update_ramp_preview()

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
	if build_mode == "foundation":
		if player and player.global_position.distance_to(pos) > max_build_distance:
			return false
		return true
	
	if player and player.global_position.distance_to(pos) > max_build_distance:
		return false
	
	return true

func _try_place_structure():
	if not preview_valid:
		print("❌ Placement impossible")
		return
	
	if build_mode == "foundation":
		_place_foundation_at(preview_position)
	elif build_mode == "ramp":
		_place_ramp_at(preview_position)

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
	
	get_tree().root.add_child(ramp_instance)
	ramp_instance.global_position = pos
	ramp_instance.rotation_degrees = preview_object.rotation_degrees
	
	print("✅ Rampe placée avec snap!")

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
