# ============================================
# Chunk.gd - CORRECTION ERREUR NIL
# ============================================

extends StaticBody3D
class_name TerrainChunk

var chunk_position: Vector2i
var chunk_size: int
var resolution: int
var noise_generator: FastNoiseLite
var height_multiplier: float

var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D
var terrain_mesh: ArrayMesh

func _ready():
	_ensure_components()

func _ensure_components():
	"""S'assurer que les composants existent avant utilisation"""
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "ChunkMesh"
		add_child(mesh_instance)
	
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "ChunkCollision"
		add_child(collision_shape)

func setup_chunk(pos: Vector2i, size: int, res: int, noise: FastNoiseLite, height: float):
	# CORRECTION: S'assurer que les composants existent
	_ensure_components()
	
	chunk_position = pos
	chunk_size = size
	resolution = res
	noise_generator = noise
	height_multiplier = height
	
	print("🔨 Setup chunk ", pos, " (taille: ", size, ", résolution: ", res, ")")
	_generate_terrain_mesh()

func _generate_terrain_mesh():
	# SÉCURITÉ: Vérifier une dernière fois
	if not mesh_instance:
		print("❌ ERREUR: mesh_instance est nil!")
		_ensure_components()
		if not mesh_instance:
			print("❌ ERREUR CRITIQUE: Impossible de créer mesh_instance")
			return
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	print("🏔️ Génération mesh chunk ", chunk_position)
	
	# Générer vertices avec positions EXACTES pour éviter gaps
	for z in range(resolution + 1):
		for x in range(resolution + 1):
			# Coordonnées monde EXACTES pour continuité parfaite
			var world_x = chunk_position.x * chunk_size + (x * chunk_size / float(resolution))
			var world_z = chunk_position.y * chunk_size + (z * chunk_size / float(resolution))
			
			# Position locale dans le chunk  
			var local_x = x * chunk_size / float(resolution)
			var local_z = z * chunk_size / float(resolution)
			
			# Hauteur basée sur coordonnées monde pour continuité
			var height = 0.0
			if noise_generator:
				height = noise_generator.get_noise_2d(world_x, world_z) * height_multiplier
			
			vertices.append(Vector3(local_x, height, local_z))
			uvs.append(Vector2(x / float(resolution), z / float(resolution)))
	
	# Ordre correct des triangles pour face culling
	for z in range(resolution):
		for x in range(resolution):
			var i = z * (resolution + 1) + x
			
			# Triangle 1: sens anti-horaire vu de dessus
			indices.append(i)
			indices.append(i + 1)
			indices.append(i + resolution + 1)
			
			# Triangle 2: sens anti-horaire vu de dessus  
			indices.append(i + 1)
			indices.append(i + resolution + 2)
			indices.append(i + resolution + 1)
	
	print("🔺 Triangles générés: ", indices.size() / 3, " avec ordre correct")
	
	# Calculer normales
	normals = _calculate_normals(vertices, indices)
	
	# Assembler mesh
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals  
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	# Créer mesh avec vérification
	terrain_mesh = ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# CORRECTION: Vérifier que mesh_instance existe toujours
	if mesh_instance and is_instance_valid(mesh_instance):
		mesh_instance.mesh = terrain_mesh
		print("✅ Mesh assigné avec succès")
	else:
		print("❌ mesh_instance invalide lors de l'assignation")
		return
	
	# Collision
	if collision_shape and is_instance_valid(collision_shape):
		var collision_mesh = terrain_mesh.create_trimesh_shape()
		collision_shape.shape = collision_mesh
		print("✅ Collision assignée avec succès")
	
	# Matériau
	_apply_terrain_material()
	
	print("✅ Chunk ", chunk_position, " généré: ", vertices.size(), " vertices, ", indices.size()/3, " triangles")

func _calculate_normals(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	
	# Initialiser toutes les normales à zéro
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO
	
	# Calculer normales des faces
	for i in range(0, indices.size(), 3):
		if i + 2 < indices.size():
			var i1 = indices[i]
			var i2 = indices[i + 1]  
			var i3 = indices[i + 2]
			
			if i1 < vertices.size() and i2 < vertices.size() and i3 < vertices.size():
				var v1 = vertices[i1]
				var v2 = vertices[i2]
				var v3 = vertices[i3]
				
				var face_normal = (v2 - v1).cross(v3 - v1).normalized()
				
				normals[i1] += face_normal
				normals[i2] += face_normal
				normals[i3] += face_normal
	
	# Normaliser toutes les normales
	for i in range(normals.size()):
		if normals[i].length() > 0.001:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP
	
	return normals

func _apply_terrain_material():
	if not mesh_instance or not is_instance_valid(mesh_instance):
		print("⚠️ Impossible d'appliquer le matériau: mesh_instance invalide")
		return
		
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.7, 0.2)
	material.roughness = 0.8
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	mesh_instance.material_override = material

# Version simple de secours si problème persiste
func _generate_simple_plane():
	print("🔧 Génération plane simple pour chunk ", chunk_position)
	
	_ensure_components()
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()
	
	# 4 vertices d'un carré
	vertices.append(Vector3(0, 0, 0))
	vertices.append(Vector3(chunk_size, 0, 0))
	vertices.append(Vector3(0, 0, chunk_size))
	vertices.append(Vector3(chunk_size, 0, chunk_size))
	
	# UVs
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(0, 1))
	uvs.append(Vector2(1, 1))
	
	# Normales vers le haut
	for i in range(4):
		normals.append(Vector3.UP)
	
	# 2 triangles
	indices.append(0)
	indices.append(1)
	indices.append(2)
	
	indices.append(1)
	indices.append(3)
	indices.append(2)
	
	# Assembler
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	# Créer mesh
	terrain_mesh = ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	if mesh_instance and is_instance_valid(mesh_instance):
		mesh_instance.mesh = terrain_mesh
	
	# Collision simple
	if collision_shape and is_instance_valid(collision_shape):
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(chunk_size, 0.1, chunk_size)
		collision_shape.shape = box_shape
	
	# Matériau
	_apply_terrain_material()
	
	print("✅ Plan simple créé pour chunk ", chunk_position)
