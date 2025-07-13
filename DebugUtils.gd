# ============================================
# DebugUtils.gd - Utilitaires de debug pour diagnostiquer les problèmes de chunks
# ============================================
# Créez ce fichier dans scripts/utils/DebugUtils.gd

extends Node

# Ajouter ce script au GameManager ou créer un singleton pour les fonctions de debug

static func debug_chunk_system():
	"""Diagnostic complet du système de chunks"""
	print("🔍 === DIAGNOSTIC SYSTÈME DE CHUNKS ===")
	
	var terrain_manager = _get_terrain_manager()
	var player = _get_player()
	
	if not terrain_manager:
		print("❌ TerrainManager non trouvé!")
		return
	
	if not player:
		print("❌ Player non trouvé!")
		return
	
	print("✅ Managers trouvés")
	
	# Info joueur
	var player_pos = player.global_position
	var player_chunk = Vector2i(
		int(floor(player_pos.x / terrain_manager.chunk_size)),
		int(floor(player_pos.z / terrain_manager.chunk_size))
	)
	
	print("🚶 Joueur:")
	print("  Position: ", player_pos)
	print("  Chunk calculé: ", player_chunk)
	print("  Chunk manager: ", terrain_manager.player_chunk_pos)
	print("  Correspond: ", player_chunk == terrain_manager.player_chunk_pos)
	
	# Info chunks
	print("📦 Chunks:")
	print("  Chargés: ", terrain_manager.loaded_chunks.size())
	print("  View distance: ", terrain_manager.view_distance)
	print("  Unload distance: ", terrain_manager.unload_distance)
	
	# Vérifier la couverture autour du joueur
	_check_chunk_coverage(terrain_manager, player_chunk)
	
	print("===========================================")

static func _check_chunk_coverage(terrain_manager: TerrainManager, player_chunk: Vector2i):
	"""Vérifier si tous les chunks nécessaires autour du joueur sont chargés"""
	print("🔎 Couverture chunks autour du joueur:")
	
	var missing_chunks = []
	var view_dist = terrain_manager.view_distance
	
	for x in range(player_chunk.x - view_dist, player_chunk.x + view_dist + 1):
		for z in range(player_chunk.y - view_dist, player_chunk.y + view_dist + 1):
			var chunk_pos = Vector2i(x, z)
			var chunk_key = str(chunk_pos.x) + "," + str(chunk_pos.y)
			
			if not terrain_manager.loaded_chunks.has(chunk_key):
				missing_chunks.append(chunk_pos)
	
	if missing_chunks.is_empty():
		print("  ✅ Tous les chunks nécessaires sont chargés")
	else:
		print("  ❌ Chunks manquants: ", missing_chunks.size())
		for i in range(min(5, missing_chunks.size())):  # Afficher max 5
			print("    - ", missing_chunks[i])
		if missing_chunks.size() > 5:
			print("    ... et ", missing_chunks.size() - 5, " autres")

static func debug_chunk_positions():
	"""Afficher les positions de tous les chunks chargés"""
	print("🗺️ === POSITIONS DES CHUNKS ===")
	
	var terrain_manager = _get_terrain_manager()
	if not terrain_manager:
		print("❌ TerrainManager non trouvé!")
		return
	
	print("Chunks chargés: ", terrain_manager.loaded_chunks.size())
	
	var chunks_by_distance = []
	var player_chunk = terrain_manager.player_chunk_pos
	
	for key in terrain_manager.loaded_chunks.keys():
		var parts = key.split(",")
		var chunk_pos = Vector2i(int(parts[0]), int(parts[1]))
		var distance = max(
			abs(chunk_pos.x - player_chunk.x),
			abs(chunk_pos.y - player_chunk.y)
		)
		
		chunks_by_distance.append({
			"pos": chunk_pos,
			"key": key,
			"distance": distance,
			"chunk": terrain_manager.loaded_chunks[key]
		})
	
	# Trier par distance
	chunks_by_distance.sort_custom(func(a, b): return a.distance < b.distance)
	
	print("Chunks triés par distance du joueur:")
	for chunk_info in chunks_by_distance:
		var status = "✅" if is_instance_valid(chunk_info.chunk) else "❌"
		print("  ", status, " ", chunk_info.pos, " (dist: ", chunk_info.distance, ")")
	
	print("===============================")

static func test_chunk_loading_unloading():
	"""Test de chargement/déchargement des chunks"""
	print("🧪 === TEST CHARGEMENT/DÉCHARGEMENT ===")
	
	var terrain_manager = _get_terrain_manager()
	var player = _get_player()
	
	if not terrain_manager or not player:
		print("❌ Managers non trouvés!")
		return
	
	print("Test en cours...")
	
	# Sauvegarder l'état initial
	var initial_pos = player.global_position
	var initial_chunks = terrain_manager.loaded_chunks.size()
	
	print("État initial: ", initial_chunks, " chunks")
	
	# Téléporter le joueur loin
	var test_pos = initial_pos + Vector3(500, 0, 500)  # 500m plus loin
	player.teleport_to_position(test_pos)
	
	# Attendre la mise à jour
	await _wait_frames(10)
	
	var after_teleport_chunks = terrain_manager.loaded_chunks.size()
	print("Après téléportation: ", after_teleport_chunks, " chunks")
	
	# Retourner à la position initiale
	player.teleport_to_position(initial_pos)
	
	# Attendre la mise à jour
	await _wait_frames(10)
	
	var final_chunks = terrain_manager.loaded_chunks.size()
	print("Retour position initiale: ", final_chunks, " chunks")
	
	print("✅ Test terminé")
	print("=====================================")

static func force_chunk_reload():
	"""Forcer le rechargement de tous les chunks"""
	print("🔄 === RECHARGEMENT FORCÉ DES CHUNKS ===")
	
	var terrain_manager = _get_terrain_manager()
	if not terrain_manager:
		print("❌ TerrainManager non trouvé!")
		return
	
	# Sauvegarder la position du joueur
	var player_pos = terrain_manager.player_chunk_pos
	
	print("Suppression de tous les chunks...")
	
	# Supprimer tous les chunks
	for chunk in terrain_manager.loaded_chunks.values():
		if is_instance_valid(chunk):
			chunk.queue_free()
	
	terrain_manager.loaded_chunks.clear()
	
	# Attendre que les chunks soient supprimés
	await _wait_frames(5)
	
	print("Rechargement autour de: ", player_pos)
	
	# Forcer une mise à jour
	terrain_manager._update_chunks()
	
	print("✅ Rechargement terminé: ", terrain_manager.loaded_chunks.size(), " chunks")
	print("========================================")

static func show_chunk_grid_in_3d():
	"""Afficher une grille visuelle des chunks en 3D (debug visuel)"""
	print("🎨 === AFFICHAGE GRILLE CHUNKS ===")
	
	var terrain_manager = _get_terrain_manager()
	if not terrain_manager:
		print("❌ TerrainManager non trouvé!")
		return
	
	# Créer des marqueurs visuels pour chaque chunk
	var debug_parent = Node3D.new()
	debug_parent.name = "ChunkDebugGrid"
	terrain_manager.add_child(debug_parent)
	
	for key in terrain_manager.loaded_chunks.keys():
		var parts = key.split(",")
		var chunk_pos = Vector2i(int(parts[0]), int(parts[1]))
		
		# Créer un marqueur visuel
		var marker = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(0.5, 10, 0.5)  # Pilier vertical
		marker.mesh = box_mesh
		
		# Matériau coloré
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.RED
		material.flags_unshaded = true
		marker.material_override = material
		
		# Position au centre du chunk
		marker.position = Vector3(
			chunk_pos.x * terrain_manager.chunk_size + terrain_manager.chunk_size * 0.5,
			5,
			chunk_pos.y * terrain_manager.chunk_size + terrain_manager.chunk_size * 0.5
		)
		
		debug_parent.add_child(marker)
	
	print("✅ Grille de debug créée (", terrain_manager.loaded_chunks.size(), " marqueurs)")
	print("Pour supprimer: Cherchez 'ChunkDebugGrid' dans la scène")
	print("==================================")

# ============================================
# FONCTIONS UTILITAIRES
# ============================================

static func _get_terrain_manager() -> TerrainManager:
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		return tree.get_first_node_in_group("world") as TerrainManager
	return null

static func _get_player() -> Player:
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		return tree.get_first_node_in_group("player") as Player
	return null

static func _wait_frames(frame_count: int):
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		for i in frame_count:
			await tree.process_frame

# ============================================
# FONCTIONS À AJOUTER AU GAMEMANAGER
# ============================================

# Ajoutez ces fonctions à votre GameManager.gd dans _input():
"""
# Dans GameManager._input():
if event.is_action_pressed("ui_select") and event.keycode == KEY_F3:  # F3
	DebugUtils.debug_chunk_system()

if event.is_action_pressed("ui_select") and event.keycode == KEY_F4:  # F4
	DebugUtils.debug_chunk_positions()

if event.is_action_pressed("ui_select") and event.keycode == KEY_F5:  # F5
	DebugUtils.force_chunk_reload()

if event.is_action_pressed("ui_select") and event.keycode == KEY_F6:  # F6
	DebugUtils.show_chunk_grid_in_3d()
"""
