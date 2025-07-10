# ============================================
# CORRECTION 2: ConstructionManager.gd (version simplifiée)
# ============================================
# Remplacez le contenu de scenes/Construction/ConstructionManager.gd par ceci :

extends Node3D
class_name ConstructionManager

@export var foundation_size: float = 4.0
@export var max_build_distance: float = 10.0

var is_building: bool = false
var preview_object: Node3D
var foundation_material: StandardMaterial3D
var preview_material: StandardMaterial3D

var player: Node3D
var camera: Camera3D

func _ready():
	add_to_group("construction_manager")
	_setup_materials()
	
	await get_tree().process_frame
	_find_references()

func _find_references():
	player = get_tree().get_first_node_in_group("player")
	if player:
		camera = player.get_node("Head/Camera3D")

func _setup_materials():
	foundation_material = StandardMaterial3D.new()
	foundation_material.albedo_color = Color(0.7, 0.7, 0.7)
	
	preview_material = StandardMaterial3D.new()
	preview_material.albedo_color = Color(0.5, 1.0, 0.5, 0.7)
	preview_material.flags_transparent = true

func _input(event):
	if event.is_action_pressed("build_mode"):
		toggle_build_mode()
	
	if is_building and event.is_action_pressed("ui_accept"):
		_place_foundation()

func toggle_build_mode():
	is_building = !is_building
	print("Mode construction: ", "ON" if is_building else "OFF")

func _place_foundation():
	if not player:
		return
	
	# Position simple devant le joueur
	var forward = player.get_look_direction()
	var spawn_pos = player.global_position + forward * 5.0
	spawn_pos.y = 0  # Au niveau du sol
	
	_create_simple_foundation(spawn_pos)
	print("Fondation placée à: ", spawn_pos)

func _create_simple_foundation(pos: Vector3):
	# Créer une fondation simple sans fichier .tscn
	var foundation = StaticBody3D.new()
	
	# Mesh visuel
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(foundation_size, 0.2, foundation_size)
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = foundation_material
	foundation.add_child(mesh_instance)
	
	# Collision
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(foundation_size, 0.2, foundation_size)
	collision_shape.shape = box_shape
	foundation.add_child(collision_shape)
	
	# Ajouter au monde
	get_tree().root.add_child(foundation)
	foundation.global_position = pos
