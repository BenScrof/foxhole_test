# ============================================
# TerrainManager.gd - VERSION OPTIMISÉE MÉMOIRE
# ============================================

extends Node3D
class_name TerrainManager

# Paramètres des chunks
@export var chunk_size: int = 16
@export var chunk_resolution: int = 16
@export var view_distance: int = 20         # RÉDUIT pour moins de charge
@export var unload_distance: int = 24
@export var max_chunks: int = 100          # LIMITE mémoire

# Paramètres du terrain
@export var terrain_height: float = 3.0
@export var terrain_scale: float = 0.01
@export var terrain_octaves: int = 2

# Optimisations
@export_group("Optimisations")
@export var enable_lod: bool = true        # Level of Detail
@export var lod_distance: int = 6          # Distance pour LOD réduit
@export var update_frequency: float = 0.5  # Mise à jour toutes les 0.5s
@export var enable_pooling: bool = true    # Pool de chunks
@export var pool_size: int = 20            # Taille du pool
@export var chunks_per_frame: int = 8      # Chunks générés par frame
@export var chunks_unload_per_frame: int = 5  # Chunks déchargés par frame

# Données internes
var loaded_chunks: Dictionary = {}
var chunk_pool: Array[Node3D] = []         # Pool pour réutilisation
var player_chunk_pos: Vector2i = Vector2i(9999, 9999)
var noise: FastNoiseLite
var chunk_scene: PackedScene

# Cache et optimisations
var height_cache: Dictionary = {}          # Cache des hauteurs
var last_update_time: float = 0.0
var chunks_to_load: Array[Vector2i] = []   # Queue de chargement
var chunks_to_unload: Array[String] = []   # Queue de déchargement

# Statistiques
var total_chunks_created: int = 0
var chunks_from_pool: int = 0

func _ready():
	add_to_group("world")
	print("🌍 === TERRAIN MANAGER OPTIMISÉ ===")
	
	_setup_noise()
	chunk_scene = preload("res://scenes/World/Chunk.tscn")
	
	# Initialiser le pool
	if enable_pooling:
		_initialize_chunk_pool()
	
	# Générer zone initiale plus petite
	_generate_initial_area()
	
	print("✅ Terrain optimisé prêt: ", loaded_chunks.size(), " chunks, pool: ", chunk_pool.size())
	print("⚡ Vitesse: ", chunks_per_frame, " chunks/frame")

func _setup_noise():
	noise = FastNoiseLite.new()
	noise.seed = 42
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = terrain_scale
	noise.fractal_octaves = terrain_octaves

func _initialize_chunk_pool():
	"""Créer un pool de chunks réutilisables"""
	print("🏊 Initialisation pool de chunks...")
	
	for i in range(pool_size):
		var chunk_instance = chunk_scene.instantiate()
		chunk_instance.visible = false
		chunk_instance.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(chunk_instance)
		chunk_pool.append(chunk_instance)
	
	print("📦 Pool créé: ", chunk_pool.size(), " chunks")

func _generate_initial_area():
	"""Zone initiale chargée immédiatement pour éviter que le joueur tombe"""
	print("🚀 Génération immédiate de la zone initiale...")
	
	for x in range(-2, 3):  # -2 à +2 = 5 chunks
		for z in range(-2, 3):
			var chunk_pos = Vector2i(x, z)
			_load_chunk(chunk_pos)  # Chargement immédiat
	
	print("📦 Zone initiale générée immédiatement: ", loaded_chunks.size(), " chunks")

func _process(_delta):
	# Limitation de fréquence des mises à jour
	var current_time = Time.get_time_dict_from_system()["second"]
	if current_time - last_update_time < update_frequency:
		return
	
	last_update_time = current_time
	
	# Traiter les queues par petits paquets
	_process_chunk_queue()
	_process_unload_queue()

func update_player_position(player_pos: Vector3):
	var new_chunk_pos = Vector2i(
		int(floor(player_pos.x / chunk_size)),
		int(floor(player_pos.z / chunk_size))
	)
	
	if new_chunk_pos != player_chunk_pos:
		player_chunk_pos = new_chunk_pos
		_queue_chunks_update()

func _queue_chunks_update():
	"""Mettre en queue les chunks à charger/décharger"""
	chunks_to_load.clear()
	chunks_to_unload.clear()
	
	# Queue des chunks à charger
	for x in range(player_chunk_pos.x - view_distance, player_chunk_pos.x + view_distance + 1):
		for z in range(player_chunk_pos.y - view_distance, player_chunk_pos.y + view_distance + 1):
			var chunk_pos = Vector2i(x, z)
			var chunk_key = _pos_to_key(chunk_pos)
			
			if not loaded_chunks.has(chunk_key):
				chunks_to_load.append(chunk_pos)
	
	# Queue des chunks à décharger
	for chunk_key in loaded_chunks.keys():
		var chunk_pos = _key_to_pos(chunk_key)
		var distance = player_chunk_pos.distance_to(Vector2(chunk_pos))
		
		if distance > unload_distance:
			chunks_to_unload.append(chunk_key)
	
	print("📋 Queue: ", chunks_to_load.size(), " à charger, ", chunks_to_unload.size(), " à décharger")

func _process_chunk_queue():
	"""Traiter la queue de chargement par petits paquets"""
	var processed = 0
	
	while chunks_to_load.size() > 0 and processed < chunks_per_frame:
		var chunk_pos = chunks_to_load.pop_front()
		
		# Vérifier limite mémoire
		if loaded_chunks.size() >= max_chunks:
			print("⚠️ Limite chunks atteinte: ", max_chunks)
			break
		
		_load_chunk(chunk_pos)
		processed += 1
	
	if processed > 0:
		print("📦 Chargé ", processed, " chunks cette frame")

func _process_unload_queue():
	"""Traiter la queue de déchargement"""
	var processed = 0
	
	while chunks_to_unload.size() > 0 and processed < chunks_unload_per_frame:
		var chunk_key = chunks_to_unload.pop_front()
		_unload_chunk(chunk_key)
		processed += 1
	
	if processed > 0:
		print("🗑️ Déchargé ", processed, " chunks cette frame")

func _load_chunk(chunk_pos: Vector2i):
	var chunk_key = _pos_to_key(chunk_pos)
	
	if loaded_chunks.has(chunk_key):
		return
	
	var chunk_instance = _get_chunk_from_pool()
	var world_pos = Vector3(
		chunk_pos.x * chunk_size,
		0,
		chunk_pos.y * chunk_size
	)
	
	chunk_instance.position = world_pos
	chunk_instance.visible = true
	chunk_instance.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Déterminer résolution selon distance (LOD)
	var distance = player_chunk_pos.distance_to(Vector2(chunk_pos))
	var resolution = chunk_resolution
	
	if enable_lod and distance > lod_distance:
		resolution = max(8, chunk_resolution / 2)  # LOD réduit
	
	chunk_instance.setup_chunk(chunk_pos, chunk_size, resolution, noise, terrain_height)
	loaded_chunks[chunk_key] = chunk_instance
	
	total_chunks_created += 1

func _unload_chunk(chunk_key: String):
	"""Décharger un chunk et le remettre dans le pool"""
	if not loaded_chunks.has(chunk_key):
		return
	
	var chunk_instance = loaded_chunks[chunk_key]
	loaded_chunks.erase(chunk_key)
	
	# Remettre dans le pool si activé
	if enable_pooling and chunk_pool.size() < pool_size:
		chunk_instance.visible = false
		chunk_instance.process_mode = Node.PROCESS_MODE_DISABLED
		chunk_pool.append(chunk_instance)
	else:
		# Sinon détruire
		chunk_instance.queue_free()

func _get_chunk_from_pool() -> Node3D:
	"""Récupérer un chunk du pool ou en créer un nouveau"""
	if enable_pooling and chunk_pool.size() > 0:
		chunks_from_pool += 1
		return chunk_pool.pop_back()
	else:
		return chunk_scene.instantiate()

func _pos_to_key(pos: Vector2i) -> String:
	return str(pos.x) + "," + str(pos.y)

func _key_to_pos(key: String) -> Vector2i:
	var parts = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func get_terrain_height_at_position(world_pos: Vector3) -> float:
	"""Version avec cache pour optimiser"""
	var cache_key = str(int(world_pos.x)) + "," + str(int(world_pos.z))
	
	if height_cache.has(cache_key):
		return height_cache[cache_key]
	
	var height = 0.0
	if noise:
		height = noise.get_noise_2d(world_pos.x, world_pos.z) * terrain_height
	
	# Limiter taille du cache
	if height_cache.size() < 1000:
		height_cache[cache_key] = height
	
	return height

func debug_chunks():
	print("=== DEBUG TERRAIN OPTIMISÉ ===")
	print("Chunks chargés: ", loaded_chunks.size(), "/", max_chunks)
	print("Pool disponible: ", chunk_pool.size())
	print("Chunks créés total: ", total_chunks_created)
	print("Chunks du pool: ", chunks_from_pool)
	print("Cache hauteurs: ", height_cache.size())
	print("Queue chargement: ", chunks_to_load.size())
	print("Queue déchargement: ", chunks_to_unload.size())
	print("Position joueur: ", player_chunk_pos)
	print("Vitesse génération: ", chunks_per_frame, " chunks/frame")
	print("Vitesse déchargement: ", chunks_unload_per_frame, " chunks/frame")
	print("==============================")

func clear_height_cache():
	"""Nettoyer le cache si nécessaire"""
	height_cache.clear()
	print("🧹 Cache hauteurs nettoyé")

func get_memory_usage() -> Dictionary:
	"""Statistiques d'utilisation mémoire"""
	return {
		"loaded_chunks": loaded_chunks.size(),
		"pool_size": chunk_pool.size(),
		"height_cache_size": height_cache.size(),
		"total_created": total_chunks_created,
		"pool_reused": chunks_from_pool
	}

func force_generate_around_player(radius: int = 3):
	"""Génération forcée immédiate autour du joueur (urgence)"""
	print("🚨 Génération d'urgence autour du joueur...")
	
	var generated = 0
	for x in range(player_chunk_pos.x - radius, player_chunk_pos.x + radius + 1):
		for z in range(player_chunk_pos.y - radius, player_chunk_pos.y + radius + 1):
			var chunk_pos = Vector2i(x, z)
			var chunk_key = _pos_to_key(chunk_pos)
			
			if not loaded_chunks.has(chunk_key):
				_load_chunk(chunk_pos)
				generated += 1
	
	print("⚡ Génération d'urgence terminée: ", generated, " chunks")

func set_generation_speed(speed: String):
	"""Ajuster la vitesse de génération selon les besoins"""
	match speed:
		"slow":
			chunks_per_frame = 2
			chunks_unload_per_frame = 3
			print("🐌 Vitesse lente: 2 chunks/frame")
		"normal":
			chunks_per_frame = 8
			chunks_unload_per_frame = 5
			print("🚶 Vitesse normale: 8 chunks/frame")
		"fast":
			chunks_per_frame = 16
			chunks_unload_per_frame = 8
			print("🏃 Vitesse rapide: 16 chunks/frame")
		"instant":
			chunks_per_frame = 50
			chunks_unload_per_frame = 20
			print("⚡ Vitesse instantanée: 50 chunks/frame")
