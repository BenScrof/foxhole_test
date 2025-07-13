# ============================================
# TerrainManager.gd - VERSION CORRIGÉE - Gestion complète des chunks
# ============================================
# Remplacez scenes/World/TerrainManager.gd par ceci :

extends Node3D
class_name TerrainManager

# Paramètres des chunks
@export var chunk_size: int = 16
@export var chunk_resolution: int = 16
@export var view_distance: int = 8        # Distance de chargement des chunks
@export var unload_distance: int = 12     # Distance de déchargement (doit être > view_distance)

# Paramètres du terrain
@export var terrain_height: float = 3.0
@export var terrain_scale: float = 0.01
@export var terrain_octaves: int = 2

# Données internes
var loaded_chunks: Dictionary = {}
var player_chunk_pos: Vector2i = Vector2i(9999, 9999)  # Position impossible au départ
var last_player_position: Vector3 = Vector3.ZERO
var noise: FastNoiseLite
var chunk_scene: PackedScene

# Variables pour mise à jour continue
var update_timer: float = 0.0
var update_interval: float = 0.5  # Vérifier toutes les 0.5 secondes

# Statistiques
var chunks_loaded_this_frame: int = 0
var chunks_unloaded_this_frame: int = 0

func _ready():
	add_to_group("world")  # ← CRUCIAL pour que le player nous trouve
	print("🌍 === TERRAIN MANAGER CORRIGÉ v2.0 ===")
	
	_setup_noise()
	chunk_scene = preload("res://scenes/World/Chunk.tscn")
	
	# Attendre que le joueur soit prêt avant de générer le terrain initial
	call_deferred("_wait_for_player_and_initialize")
	
	print("✅ TerrainManager initialisé, en attente du joueur...")

func _wait_for_player_and_initialize():
	"""Attendre que le joueur soit disponible avant de générer les chunks initiaux"""
	var player = get_tree().get_first_node_in_group("player")
	var attempts = 0
	
	# Attendre jusqu'à 60 frames (1 seconde à 60fps) que le joueur soit disponible
	while not player and attempts < 60:
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
		attempts += 1
	
	if player:
		print("✅ Joueur trouvé à la position: ", player.global_position)
		# Générer les chunks initiaux autour de la position du joueur
		_generate_initial_area_around_player(player.global_position)
		# Mettre à jour la position du joueur une première fois
		update_player_position(player.global_position)
	else:
		print("⚠️ Joueur non trouvé après ", attempts, " tentatives, génération par défaut")
		_generate_initial_area_around_player(Vector3.ZERO)

func _setup_noise():
	noise = FastNoiseLite.new()
	noise.seed = 42
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = terrain_scale
	noise.fractal_octaves = terrain_octaves
	print("🎲 Générateur de bruit configuré")

func _generate_initial_area_around_player(player_pos: Vector3):
	"""Générer une zone initiale autour de la position du joueur"""
	print("🗺️ Génération zone initiale autour de: ", player_pos)
	
	# Calculer le chunk central du joueur
	var center_chunk = Vector2i(
		int(floor(player_pos.x / chunk_size)),
		int(floor(player_pos.z / chunk_size))
	)
	
	# Générer une zone autour de ce chunk central
	var initial_radius = 3  # Rayon de 3 chunks = zone 7x7
	for x in range(center_chunk.x - initial_radius, center_chunk.x + initial_radius + 1):
		for z in range(center_chunk.y - initial_radius, center_chunk.y + initial_radius + 1):
			var chunk_pos = Vector2i(x, z)
			_load_chunk(chunk_pos)
	
	print("📦 Zone initiale générée: ", loaded_chunks.size(), " chunks autour de ", center_chunk)

func _process(delta):
	"""Mise à jour continue du système de chunks"""
	update_timer += delta
	
	# Vérifier périodiquement les chunks même si le joueur n'a pas changé de chunk
	if update_timer >= update_interval:
		update_timer = 0.0
		_periodic_chunk_update()

func _periodic_chunk_update():
	"""Mise à jour périodique pour s'assurer que tous les chunks nécessaires sont chargés"""
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var current_pos = player.global_position
		# Forcer une mise à jour si le joueur a bougé significativement
		if current_pos.distance_to(last_player_position) > chunk_size * 0.25:  # 1/4 de chunk
			update_player_position(current_pos)

func update_player_position(player_pos: Vector3):
	"""Mettre à jour la position du joueur et gérer les chunks"""
	last_player_position = player_pos
	
	# Calculer la nouvelle position du chunk du joueur
	var new_chunk_pos = Vector2i(
		int(floor(player_pos.x / chunk_size)),
		int(floor(player_pos.z / chunk_size))
	)
	
	# Ne mettre à jour que si le joueur a changé de chunk OU si c'est la première fois
	var force_update = (player_chunk_pos == Vector2i(9999, 9999))  # Première initialisation
	
	if new_chunk_pos != player_chunk_pos or force_update:
		print("🚶 Joueur dans chunk: ", new_chunk_pos, " (monde: ", 
			  int(player_pos.x), ",", int(player_pos.y), ",", int(player_pos.z), ")")
		
		player_chunk_pos = new_chunk_pos
		_update_chunks()

func _update_chunks():
	"""Mettre à jour les chunks : charger les nouveaux, décharger les anciens"""
	chunks_loaded_this_frame = 0
	chunks_unloaded_this_frame = 0
	
	# 1. CHARGEMENT des nouveaux chunks
	_load_chunks_in_range()
	
	# 2. DÉCHARGEMENT des chunks trop loin
	_unload_distant_chunks()
	
	# 3. Rapport des changements
	if chunks_loaded_this_frame > 0 or chunks_unloaded_this_frame > 0:
		print("📦 Chunks: +", chunks_loaded_this_frame, " -", chunks_unloaded_this_frame, 
			  " (total: ", loaded_chunks.size(), ")")

func _load_chunks_in_range():
	"""Charger tous les chunks dans la zone de vue"""
	for x in range(player_chunk_pos.x - view_distance, player_chunk_pos.x + view_distance + 1):
		for z in range(player_chunk_pos.y - view_distance, player_chunk_pos.y + view_distance + 1):
			var chunk_pos = Vector2i(x, z)
			var chunk_key = _pos_to_key(chunk_pos)
			
			# Charger seulement si pas déjà chargé
			if not loaded_chunks.has(chunk_key):
				_load_chunk(chunk_pos)
				chunks_loaded_this_frame += 1

func _unload_distant_chunks():
	"""Décharger les chunks trop éloignés"""
	var chunks_to_unload = []
	
	# Identifier les chunks à décharger
	for chunk_key in loaded_chunks.keys():
		var chunk_pos = _key_to_pos(chunk_key)
		var distance = max(
			abs(chunk_pos.x - player_chunk_pos.x),
			abs(chunk_pos.y - player_chunk_pos.y)
		)
		
		# Si le chunk est trop loin, le marquer pour déchargement
		if distance > unload_distance:
			chunks_to_unload.append(chunk_key)
	
	# Décharger les chunks marqués
	for chunk_key in chunks_to_unload:
		_unload_chunk(chunk_key)
		chunks_unloaded_this_frame += 1

func _load_chunk(chunk_pos: Vector2i):
	"""Charger un chunk spécifique"""
	var chunk_key = _pos_to_key(chunk_pos)
	
	# Vérifier si déjà chargé (sécurité)
	if loaded_chunks.has(chunk_key):
		return
	
	# Créer l'instance du chunk
	var chunk_instance = chunk_scene.instantiate()
	add_child(chunk_instance)
	
	# Positionner le chunk exactement
	var world_pos = Vector3(
		chunk_pos.x * chunk_size,
		0,
		chunk_pos.y * chunk_size
	)
	chunk_instance.position = world_pos
	
	# Configurer le chunk
	chunk_instance.setup_chunk(chunk_pos, chunk_size, chunk_resolution, noise, terrain_height)
	
	# Stocker la référence
	loaded_chunks[chunk_key] = chunk_instance

func _unload_chunk(chunk_key: String):
	"""Décharger un chunk spécifique"""
	if not loaded_chunks.has(chunk_key):
		return
	
	var chunk_instance = loaded_chunks[chunk_key]
	
	# Retirer de la scène
	if chunk_instance and is_instance_valid(chunk_instance):
		chunk_instance.queue_free()
	
	# Retirer de notre dictionnaire
	loaded_chunks.erase(chunk_key)

func _pos_to_key(pos: Vector2i) -> String:
	"""Convertir position en clé unique"""
	return str(pos.x) + "," + str(pos.y)

func _key_to_pos(key: String) -> Vector2i:
	"""Convertir clé en position"""
	var parts = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func get_terrain_height_at_position(world_pos: Vector3) -> float:
	"""Obtenir la hauteur du terrain à une position donnée"""
	if noise:
		return noise.get_noise_2d(world_pos.x, world_pos.z) * terrain_height
	return 0.0

# ============================================
# MÉTHODES DE DEBUG ET DIAGNOSTIC
# ============================================

func debug_chunks():
	"""Afficher des informations de debug sur les chunks"""
	print("=== DEBUG CHUNKS ===")
	print("Position joueur (chunk): ", player_chunk_pos)
	print("Chunks chargés: ", loaded_chunks.size())
	print("View distance: ", view_distance)
	print("Unload distance: ", unload_distance)
	
	# Afficher la position de quelques chunks
	var count = 0
	for key in loaded_chunks.keys():
		if count < 5:  # Afficher seulement les 5 premiers
			var chunk = loaded_chunks[key]
			var pos = chunk.position if chunk else "N/A"
			print("  Chunk ", key, " à position: ", pos)
		count += 1
	
	if loaded_chunks.size() > 5:
		print("  ... et ", loaded_chunks.size() - 5, " autres chunks")
	print("====================")

func force_chunk_update():
	"""Forcer une mise à jour complète des chunks (pour debug)"""
	print("🔄 Force mise à jour des chunks...")
	_update_chunks()

func get_chunk_stats() -> Dictionary:
	"""Retourner les statistiques des chunks pour l'UI de debug"""
	return {
		"loaded_count": loaded_chunks.size(),
		"player_chunk": player_chunk_pos,
		"view_distance": view_distance,
		"unload_distance": unload_distance,
		"last_loaded": chunks_loaded_this_frame,
		"last_unloaded": chunks_unloaded_this_frame
	}

# ============================================
# MÉTHODES POUR AJUSTEMENTS EN RUNTIME
# ============================================

func set_view_distance(new_distance: int):
	"""Changer la distance de vue en runtime"""
	view_distance = max(1, new_distance)
	unload_distance = max(view_distance + 2, unload_distance)
	print("🔧 View distance changée: ", view_distance)
	force_chunk_update()

func set_unload_distance(new_distance: int):
	"""Changer la distance de déchargement en runtime"""
	unload_distance = max(view_distance + 1, new_distance)
	print("🔧 Unload distance changée: ", unload_distance)
	force_chunk_update()
