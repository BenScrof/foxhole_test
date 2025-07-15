# ============================================
# Foundation.gd - Classe pour une fondation individuelle
# ============================================

extends StaticBody3D
class_name Foundation

var foundation_position: Vector3
var foundation_size: float
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D

signal foundation_destroyed(foundation: Foundation)

func _ready():
	# Créer les composants
	mesh_instance = MeshInstance3D.new()
	collision_shape = CollisionShape3D.new()
	
	add_child(mesh_instance)
	add_child(collision_shape)

func setup(pos: Vector3, size: float):
	foundation_position = pos
	foundation_size = size
	
	_create_mesh()
	_create_collision()

func _create_mesh():
	# Créer le mesh de la fondation
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(foundation_size, 0.2, foundation_size)
	
	mesh_instance.mesh = box_mesh
	
	# Appliquer le matériau
	var construction_manager = get_tree().get_first_node_in_group("construction_manager")
	if construction_manager:
		mesh_instance.material_override = construction_manager.foundation_material

func _create_collision():
	# Créer la collision
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(foundation_size, 0.2, foundation_size)
	
	collision_shape.shape = box_shape

func get_adjacent_positions() -> Array[Vector3]:
	# Retourner les positions où d'autres fondations peuvent se connecter
	var positions = []
	var offsets = [
		Vector3(foundation_size, 0, 0),    # Droite
		Vector3(-foundation_size, 0, 0),   # Gauche
		Vector3(0, 0, foundation_size),    # Avant
		Vector3(0, 0, -foundation_size)    # Arrière
	]
	
	for offset in offsets:
		positions.append(foundation_position + offset)
	
	return positions

func destroy():
	foundation_destroyed.emit(self)
	queue_free()
