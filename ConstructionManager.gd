# ============================================
# ConstructionManager.gd - Biseaux Conditionnels
# ============================================

extends Node3D
class_name ConstructionManager

@export var foundation_size: float = 4.0
@export var max_build_distance: float = 15.0
@export var grid_snap: bool = true
@export var preview_alpha: float = 0.6

@export_group("Biseaux")
@export var bevel_width: float = 0.5
@export var bevel_height: float = 0.1
@export var auto_remove_bevels: bool = true

var is_building: bool = false
var current_rotation: float = 0.0
var rotation_step: float = 90.0
var current_build_height: float = 0.0

var preview_object: MeshInstance3D
var preview_valid: bool = false
var preview_position: Vector3

var foundation_material: StandardMaterial3D
var preview_material_valid: StandardMaterial3D
var preview_material_invalid: StandardMaterial3D

var player: Player
var camera: Camera3D
var terrain_manager: TerrainManager

var placed_foundations: Array[Dictionary] = []

func _ready():
	add_to_group("construction_manager")
	_setup_materials()
	_setup_preview()
	
	await get_tree().process_frame
	_find_references()
	
	print("🔨 Construction avec biseaux conditionnels")

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

func _setup_preview():
	preview_object = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(foundation_size, 0.3, foundation_size)
	preview_object.mesh = box_mesh
	add_child(preview_object)
	preview_object.visible = false

func _input(event):
	if event.is_action_pressed("build_mode"):
		toggle_build_mode()
	
	if is_building:
		if event.is_action_pressed("height_up"):
			adjust_build_height(0.2)
		elif event.is_action_pressed("height_down"):
			adjust_build_height(-0.2)
	
	if event.is_action_pressed("rotate_building") and is_building:
		rotate_preview()
	
	if is_building and (event.is_action_pressed("ui_accept") or event.is_action_pressed("place_building")):
		_try_place_foundation()
	
	if is_building and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel_building")):
		toggle_build_mode()

func adjust_build_height(delta: float):
	current_build_height += delta
	current_build_height = clamp(current_build_height, -5.0, 10.0)
	print("🏗️ Hauteur: ", snappedf(current_build_height, 0.1), "m")

func toggle_build_mode():
	is_building = !is_building
	preview_object.visible = is_building
	current_rotation = 0.0
	
	if is_building:
		print("🔨 Mode construction")
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func rotate_preview():
	current_rotation += rotation_step
	if current_rotation >= 360:
		current_rotation = 0

func _process(_delta):
	if is_building and preview_object.visible:
		_update_preview()

func _update_preview():
	if not player or not camera:
		return
	
	var target_position = _calculate_build_position()
	
	if target_position != Vector3.INF:
		if grid_snap:
			target_position = _snap_to_grid(target_position)
		
		target_position.y = current_build_height
		preview_position = target_position
		preview_object.global_position = target_position
		preview_object.rotation_degrees.y = current_rotation
		
		preview_valid = _is_position_valid(target_position)
		
		if preview_valid:
			preview_object.material_override = preview_material_valid
		else:
			preview_object.material_override = preview_material_invalid
		
		preview_object.visible = true
	else:
		preview_object.visible = false

func _calculate_build_position() -> Vector3:
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * max_build_distance
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_point = result.position
		if player.global_position.distance_to(hit_point) <= max_build_distance:
			return hit_point
	
	return Vector3.INF

func _snap_to_grid(pos: Vector3) -> Vector3:
	var snapped_x = round(pos.x / foundation_size) * foundation_size
	var snapped_z = round(pos.z / foundation_size) * foundation_size
	return Vector3(snapped_x, pos.y, snapped_z)

func _is_position_valid(pos: Vector3) -> bool:
	var grid_2d = Vector2i(int(pos.x / foundation_size), int(pos.z / foundation_size))
	
	for foundation_data in placed_foundations:
		if foundation_data.grid_pos == grid_2d:
			return false
	
	if player and player.global_position.distance_to(pos) > max_build_distance:
		return false
	
	return true

func _try_place_foundation():
	if not preview_valid:
		print("❌ Impossible de placer ici!")
		return
	
	_place_foundation_at(preview_position)

func _place_foundation_at(pos: Vector3):
	var grid_2d = Vector2i(int(pos.x / foundation_size), int(pos.z / foundation_size))
	
	# Créer la fondation avec biseaux par défaut
	var foundation = _create_beveled_foundation(pos, grid_2d)
	
	var foundation_data = {
		"node": foundation,
		"height": pos.y,
		"grid_pos": grid_2d,
		"mesh_instance": foundation.get_child(0)
	}
	
	placed_foundations.append(foundation_data)
	
	# Mettre à jour cette fondation et ses voisines
	if auto_remove_bevels:
		_update_bevels_around(grid_2d)
	
	print("✅ Fondation placée! Total: ", placed_foundations.size())

func _create_beveled_foundation(pos: Vector3, grid_pos: Vector2i) -> StaticBody3D:
	var foundation = StaticBody3D.new()
	foundation.name = "BeveledFoundation_" + str(placed_foundations.size())
	
	var mesh_instance = MeshInstance3D.new()
	var mesh = _create_foundation_mesh_with_bevels(grid_pos)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = foundation_material
	foundation.add_child(mesh_instance)
	
	# Collision simple
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(foundation_size, 0.3, foundation_size)
	collision_shape.shape = box_shape
	foundation.add_child(collision_shape)
	
	foundation.rotation_degrees.y = current_rotation
	get_tree().root.add_child(foundation)
	foundation.global_position = pos
	
	return foundation

func _create_foundation_mesh_with_bevels(grid_pos: Vector2i) -> ArrayMesh:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	var half_size = foundation_size / 2.0
	var bevel_size = bevel_width
	var top_height = 0.15
	
	# Déterminer quels côtés ont des voisins
	var has_neighbors = {
		"right": _has_neighbor(grid_pos + Vector2i(1, 0)),
		"left": _has_neighbor(grid_pos + Vector2i(-1, 0)),
		"back": _has_neighbor(grid_pos + Vector2i(0, 1)),
		"forward": _has_neighbor(grid_pos + Vector2i(0, -1))
	}
	
	var resolution = 8
	
	for z in range(resolution + 1):
		for x in range(resolution + 1):
			var local_x = (x / float(resolution) - 0.5) * foundation_size
			var local_z = (z / float(resolution) - 0.5) * foundation_size
			
			var height_adjustment = 0.0
			
			# Appliquer biseaux seulement sur les côtés sans voisins
			if local_x > half_size - bevel_size and not has_neighbors["right"]:
				var factor = (local_x - (half_size - bevel_size)) / bevel_size
				height_adjustment -= bevel_height * factor
			
			if local_x < -(half_size - bevel_size) and not has_neighbors["left"]:
				var factor = (-(half_size - bevel_size) - local_x) / bevel_size
				height_adjustment -= bevel_height * factor
			
			if local_z > half_size - bevel_size and not has_neighbors["back"]:
				var factor = (local_z - (half_size - bevel_size)) / bevel_size
				height_adjustment -= bevel_height * factor
			
			if local_z < -(half_size - bevel_size) and not has_neighbors["forward"]:
				var factor = (-(half_size - bevel_size) - local_z) / bevel_size
				height_adjustment -= bevel_height * factor
			
			vertices.append(Vector3(local_x, top_height + height_adjustment, local_z))
			normals.append(Vector3.UP)
			uvs.append(Vector2(x / float(resolution), z / float(resolution)))
	
	# Triangles
	for z in range(resolution):
		for x in range(resolution):
			var i = z * (resolution + 1) + x
			
			indices.append(i)
			indices.append(i + 1)
			indices.append(i + resolution + 1)
			
			indices.append(i + 1)
			indices.append(i + resolution + 2)
			indices.append(i + resolution + 1)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _has_neighbor(grid_pos: Vector2i) -> bool:
	for foundation_data in placed_foundations:
		if foundation_data.grid_pos == grid_pos:
			return true
	return false

func _update_bevels_around(center_grid_pos: Vector2i):
	var positions_to_update = [
		center_grid_pos,
		center_grid_pos + Vector2i(1, 0),
		center_grid_pos + Vector2i(-1, 0),
		center_grid_pos + Vector2i(0, 1),
		center_grid_pos + Vector2i(0, -1)
	]
	
	for grid_pos in positions_to_update:
		for foundation_data in placed_foundations:
			if foundation_data.grid_pos == grid_pos:
				var new_mesh = _create_foundation_mesh_with_bevels(grid_pos)
				foundation_data.mesh_instance.mesh = new_mesh
				break

func get_foundation_count() -> int:
	return placed_foundations.size()

func clear_all_foundations():
	for foundation_data in placed_foundations:
		if foundation_data.node:
			foundation_data.node.queue_free()
	placed_foundations.clear()
	current_build_height = 0.0
