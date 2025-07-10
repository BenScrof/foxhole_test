# ============================================
# Chunk.gd - Correction du face culling et orientation des triangles
# ============================================
# Remplacez scenes/World/Chunk.gd par ceci :

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
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "ChunkMesh"
	
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "ChunkCollision"
	
	add_child(mesh_instance)
	add_child(collision_shape)

func setup_chunk(pos: Vector2i, size: int, res: int, noise: FastNoiseLite, height: float):
	chunk_position = pos
	chunk_size = size
	resolution = res
	noise_generator = noise
	height_multiplier = height
	
	print("🔨 Setup chunk ", pos, " (taille: ", size, ", résolution: ", res, ")")
	_generate_terrain_mesh()

func _generate_terrain_mesh():
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
			# IMPORTANT: Coordonnées monde EXACTES pour continuité parfaite
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
	
	# CORRECTION CRUCIALE: Ordre correct des triangles pour face culling
	# En Godot, l'ordre doit être COUNTER-CLOCKWISE (sens anti-horaire) vu de dessus
	for z in range(resolution):
		for x in range(resolution):
			var i = z * (resolution + 1) + x
			
			# Configuration du quad:
			# i+res+1 ---- i+res+2
			#   |            |
			#   |            |
			#   i -------- i+1
			
			# Triangle 1: i, i+1, i+res+1 (sens anti-horaire vu de dessus)
			indices.append(i)
			indices.append(i + 1)
			indices.append(i + resolution + 1)
			
			# Triangle 2: i+1, i+res+2, i+res+1 (sens anti-horaire vu de dessus)  
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
	
	# Créer mesh
	terrain_mesh = ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = terrain_mesh
	
	# Collision
	var collision_mesh = terrain_mesh.create_trimesh_shape()
	collision_shape.shape = collision_mesh
	
	# Matériau avec culling désactivé pour test
	_apply_terrain_material()
	
	print("✅ Chunk ", chunk_position, " généré: ", vertices.size(), " vertices, ", indices.size()/3, " triangles")

func _calculate_normals(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	
	# Initialiser toutes les normales à zéro
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO
	
	# Calculer normales des faces en respectant l'ordre counter-clockwise
	for i in range(0, indices.size(), 3):
		if i + 2 < indices.size():
			var i1 = indices[i]
			var i2 = indices[i + 1]  
			var i3 = indices[i + 2]
			
			if i1 < vertices.size() and i2 < vertices.size() and i3 < vertices.size():
				var v1 = vertices[i1]
				var v2 = vertices[i2]
				var v3 = vertices[i3]
				
				# Normale avec ordre counter-clockwise
				var face_normal = (v2 - v1).cross(v3 - v1).normalized()
				
				normals[i1] += face_normal
				normals[i2] += face_normal
				normals[i3] += face_normal
	
	# Normaliser toutes les normales
	for i in range(normals.size()):
		if normals[i].length() > 0.001:  # Éviter division par zéro
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP  # Normal par défaut vers le haut
	
	return normals

func _apply_terrain_material():
	var material = StandardMaterial3D.new()
	
	# Couleur de base
	material.albedo_color = Color(0.3, 0.7, 0.2)
	material.roughness = 0.8
	material.metallic = 0.0
	
	# CORRECTION: Désactiver le face culling pour voir les deux côtés
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Option pour voir les triangles en wireframe (debug)
	# material.wireframe = true
	
	mesh_instance.material_override = material

# ============================================
# Version alternative ultra-simple pour tester
# ============================================
# Si le problème persiste, remplacez temporairement _generate_terrain_mesh() par ceci :

func _generate_simple_plane():
	print("🔧 Génération plane simple pour chunk ", chunk_position)
	
	# Créer un plan simple de 4 vertices
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()
	
	# 4 vertices d'un carré
	vertices.append(Vector3(0, 0, 0))                          # 0: coin bas-gauche
	vertices.append(Vector3(chunk_size, 0, 0))                 # 1: coin bas-droite  
	vertices.append(Vector3(0, 0, chunk_size))                 # 2: coin haut-gauche
	vertices.append(Vector3(chunk_size, 0, chunk_size))        # 3: coin haut-droite
	
	# UVs
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(0, 1))
	uvs.append(Vector2(1, 1))
	
	# Normales vers le haut
	for i in range(4):
		normals.append(Vector3.UP)
	
	# 2 triangles avec ordre correct (counter-clockwise vu de dessus)
	# Triangle 1: 0, 1, 2
	indices.append(0)
	indices.append(1)
	indices.append(2)
	
	# Triangle 2: 1, 3, 2  
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
	mesh_instance.mesh = terrain_mesh
	
	# Collision simple
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(chunk_size, 0.1, chunk_size)
	collision_shape.shape = box_shape
	collision_shape.position.y = 0
	
	# Matériau
	_apply_terrain_material()
	
	print("✅ Plan simple créé pour chunk ", chunk_position)

# ============================================
# Debug: Méthode pour vérifier l'orientation des triangles
# ============================================

func debug_triangle_orientation():
	print("=== DEBUG TRIANGLES CHUNK ", chunk_position, " ===")
	
	if not terrain_mesh:
		print("Pas de mesh à analyser")
		return
	
	var arrays = terrain_mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	
	# Analyser les premiers triangles
	for i in range(0, min(6, indices.size()), 3):
		if i + 2 < indices.size():
			var v1 = vertices[indices[i]]
			var v2 = vertices[indices[i + 1]]
			var v3 = vertices[indices[i + 2]]
			
			var normal = (v2 - v1).cross(v3 - v1)
			print("Triangle ", i/3, ": normal Y = ", normal.y, " (", "UP" if normal.y > 0 else "DOWN", ")")
	
	print("================================")
