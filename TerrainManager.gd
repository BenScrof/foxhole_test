# ============================================
# TerrainManager.gd - Correction des gaps entre chunks
# ============================================
# Remplacez scenes/World/TerrainManager.gd par ceci :

extends Node3D
class_name TerrainManager

# Paramètres des chunks
@export var chunk_size: int = 16
@export var chunk_resolution: int = 16
@export var view_distance: int = 10       # AUGMENTÉ pour couvrir plus de zone
@export var unload_distance: int = 12

# Paramètres du terrain
@export var terrain_height: float = 3.0
@export var terrain_scale: float = 0.01
@export var terrain_octaves: int = 2

# Données internes
var loaded_chunks: Dictionary = {}
var player_chunk_pos: Vector2i = Vector2i(9999, 9999)
var noise: FastNoiseLite
var chunk_scene: PackedScene

func _ready():
	add_to_group("world")  # ← CETTE LIGNE EST CRUCIALE
	print("🌍 === INITIALISATION SYSTÈME DE CHUNKS CORRIGÉ ===")
	
	_setup_noise()
	chunk_scene = preload("res://scenes/World/Chunk.tscn")
	
	# CORRECTION: Générer une zone plus large au démarrage
	print("🔧 Génération de la zone initiale 7x7...")
	_generate_initial_area()
	
	print("✅ Système de chunks prêt avec ", loaded_chunks.size(), " chunks!")

func _setup_noise():
	noise = FastNoiseLite.new()
	noise.seed = 42
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = terrain_scale
	noise.fractal_octaves = terrain_octaves
	print("🎲 Bruit configuré")

func _generate_initial_area():
	# Générer une zone 7x7 autour du centre pour éviter les gaps
	for x in range(-3, 4):  # -3 à +3 = 7 chunks
		for z in range(-3, 4):
			var chunk_pos = Vector2i(x, z)
			_load_chunk(chunk_pos)
	print("📦 Zone initiale générée: ", loaded_chunks.size(), " chunks")

func update_player_position(player_pos: Vector3):
	# Calculer position du chunk avec précision
	var new_chunk_pos = Vector2i(
		int(floor(player_pos.x / chunk_size)),
		int(floor(player_pos.z / chunk_size))
	)
	
	# Debug position moins verbeux
	if new_chunk_pos != player_chunk_pos:
		print("🚶 Chunk joueur: ", new_chunk_pos, " (monde: ", player_pos, ")")
		player_chunk_pos = new_chunk_pos
		_update_chunks()

func _update_chunks():
	# Charger tous les chunks dans la zone de vue
	var chunks_loaded = 0
	
	for x in range(player_chunk_pos.x - view_distance, player_chunk_pos.x + view_distance + 1):
		for z in range(player_chunk_pos.y - view_distance, player_chunk_pos.y + view_distance + 1):
			var chunk_pos = Vector2i(x, z)
			var chunk_key = _pos_to_key(chunk_pos)
			
			if not loaded_chunks.has(chunk_key):
				_load_chunk(chunk_pos)
				chunks_loaded += 1
	
	if chunks_loaded > 0:
		print("📦 ", chunks_loaded, " nouveaux chunks chargés")

func _load_chunk(chunk_pos: Vector2i):
	var chunk_key = _pos_to_key(chunk_pos)
	
	# Vérifier si déjà chargé
	if loaded_chunks.has(chunk_key):
		return
	
	print("🔨 Création chunk: ", chunk_pos)
	
	var chunk_instance = chunk_scene.instantiate()
	add_child(chunk_instance)
	
	# CORRECTION: Position exacte pour éviter les gaps
	var world_pos = Vector3(
		chunk_pos.x * chunk_size,
		0,
		chunk_pos.y * chunk_size
	)
	chunk_instance.position = world_pos
	
	# Configurer le chunk
	chunk_instance.setup_chunk(chunk_pos, chunk_size, chunk_resolution, noise, terrain_height)
	
	# Stocker
	loaded_chunks[chunk_key] = chunk_instance
	
	print("✅ Chunk ", chunk_pos, " à position ", world_pos)

func _pos_to_key(pos: Vector2i) -> String:
	return str(pos.x) + "," + str(pos.y)

func get_terrain_height_at_position(world_pos: Vector3) -> float:
	if noise:
		return noise.get_noise_2d(world_pos.x, world_pos.z) * terrain_height
	return 0.0
	
func debug_chunks():
	print("=== DEBUG CHUNKS ===")
	print("Chunks chargés: ", loaded_chunks.size())
	
	for key in loaded_chunks.keys():
		var chunk = loaded_chunks[key]
		var pos = chunk.position
		print("Chunk ", key, " à position: ", pos)
	
	print("Position joueur chunk: ", player_chunk_pos)
	print("====================")
