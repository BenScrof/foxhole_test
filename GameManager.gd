# ============================================
# GameManager.gd AMÉLIORÉ - State Management et Debug UI
# ============================================
# Remplacez le contenu de scripts/managers/GameManager.gd par ceci :

extends Node
class_name GameManager

# États du jeu
enum GameState {
	MENU,
	PLAYING,
	BUILDING,
	PAUSED
}

# Variables d'état
var current_state: GameState = GameState.PLAYING
var previous_state: GameState = GameState.PLAYING

# Références UI et managers
var debug_ui: DebugUI
var construction_manager: ConstructionManager
var terrain_manager: TerrainManager
var player: Player

# Statistiques de jeu
var game_start_time: float
var total_foundations_built: int = 0
var session_stats: Dictionary = {}

func _ready():
	print("🎮 === FOXHOLE FPS CONSTRUCTION GAME ===")
	print("Version: 1.0 - Debug Build")
	print("")
	print("🎯 CONTRÔLES:")
	print("  F1: Debug UI (FPS, chunks, stats)")
	print("  ZQSD: Déplacer le joueur") 
	print("  Souris: Regarder autour")
	print("  B: Mode construction ON/OFF")
	print("  R: Rotation structure (en construction)")
	print("  Entrée/Clic: Placer fondation")
	print("  Échap/Clic droit: Annuler construction")
	print("  Espace: Saut")
	print("==========================================")
	
	game_start_time = Time.get_time_dict_from_system()["hour"] * 3600 + \
					  Time.get_time_dict_from_system()["minute"] * 60 + \
					  Time.get_time_dict_from_system()["second"]
	
	_initialize_stats()
	
	# CORRECTION: Utiliser call_deferred pour l'initialisation
	call_deferred("_deferred_setup")

func _deferred_setup():
	"""Initialisation différée après que la scène soit complètement prête"""
	await _setup_managers()
	await _setup_ui()

func _setup_managers():
	"""Trouver et configurer les managers"""
	await get_tree().process_frame
	await get_tree().process_frame  # Double attente pour être sûr
	
	terrain_manager = get_tree().get_first_node_in_group("world")
	construction_manager = get_tree().get_first_node_in_group("construction_manager")
	player = get_tree().get_first_node_in_group("player")
	
	if terrain_manager:
		print("✅ TerrainManager connecté")
	else:
		print("⚠️ TerrainManager non trouvé!")
	
	if construction_manager:
		print("✅ ConstructionManager connecté")
		# Connecter aux événements de construction
		if construction_manager.has_signal("foundation_placed"):
			construction_manager.foundation_placed.connect(_on_foundation_placed)
	else:
		print("⚠️ ConstructionManager non trouvé!")
	
	if player:
		print("✅ Player connecté")
	else:
		print("⚠️ Player non trouvé!")

func _setup_ui():
	"""Charger et configurer l'interface de debug"""
	# CORRECTION: Attendre que la scène soit complètement prête
	await get_tree().process_frame
	await get_tree().process_frame  # Double attente pour être sûr
	
	var debug_scene = load("res://scenes/UI/DebugUI.tscn")
	if debug_scene:
		debug_ui = debug_scene.instantiate()
		get_tree().root.call_deferred("add_child", debug_ui)
		print("✅ Debug UI chargé (deferred)")
		
		# Connecter les événements si nécessaire (après un frame)
		await get_tree().process_frame
		if debug_ui and debug_ui.has_signal("debug_command"):
			debug_ui.debug_command.connect(_on_debug_command)
	else:
		print("⚠️ Impossible de charger DebugUI.tscn")
		print("   Créez le fichier scenes/UI/DebugUI.tscn")

func _initialize_stats():
	"""Initialiser les statistiques de session"""
	session_stats = {
		"start_time": game_start_time,
		"foundations_built": 0,
		"chunks_generated": 0,
		"distance_traveled": 0.0,
		"build_time_total": 0.0
	}

func _input(event):
	# Gestion des états globaux
	if event.is_action_pressed("ui_cancel"):
		_handle_escape_key()

func _handle_escape_key():
	"""Gestion de la touche Échap selon l'état"""
	match current_state:
		GameState.BUILDING:
			change_state(GameState.PLAYING)
		GameState.PLAYING:
			_toggle_pause()

func _toggle_pause():
	"""Toggle pause du jeu"""
	if current_state == GameState.PAUSED:
		change_state(previous_state)
		get_tree().paused = false
		print("⏵️ Jeu repris")
	else:
		previous_state = current_state
		change_state(GameState.PAUSED)
		get_tree().paused = true
		print("⏸️ Jeu en pause")

func change_state(new_state: GameState):
	"""Changer l'état du jeu"""
	if new_state == current_state:
		return
	
	var old_state = current_state
	current_state = new_state
	
	_on_state_changed(old_state, new_state)

func _on_state_changed(old_state: GameState, new_state: GameState):
	"""Réagir au changement d'état"""
	print("🔄 État: ", _state_to_string(old_state), " → ", _state_to_string(new_state))
	
	match new_state:
		GameState.PLAYING:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		GameState.BUILDING:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		GameState.PAUSED:
			pass  # Géré dans _toggle_pause()

func _state_to_string(state: GameState) -> String:
	"""Convertir état en string pour debug"""
	match state:
		GameState.MENU: return "MENU"
		GameState.PLAYING: return "PLAYING"
		GameState.BUILDING: return "BUILDING"
		GameState.PAUSED: return "PAUSED"
		_: return "UNKNOWN"

func _on_foundation_placed():
	"""Callback quand une fondation est placée"""
	total_foundations_built += 1
	session_stats.foundations_built += 1
	
	print("🏗️ Fondation #", total_foundations_built, " construite!")

func _on_debug_command(command: String):
	"""Traiter les commandes de debug"""
	match command:
		"clear_foundations":
			if construction_manager:
				construction_manager.clear_all_foundations()
				total_foundations_built = 0
		"reset_stats":
			_initialize_stats()
		"show_stats":
			_print_session_stats()

func _print_session_stats():
	"""Afficher les statistiques de session"""
	print("📊 === STATISTIQUES DE SESSION ===")
	print("Fondations construites: ", session_stats.foundations_built)
	print("Chunks générés: ", session_stats.chunks_generated if terrain_manager else 0)
	print("Distance parcourue: ", int(session_stats.distance_traveled), "m")
	print("Temps de construction: ", int(session_stats.build_time_total), "s")
	print("================================")

# ============================================
# Getters pour les autres systèmes
# ============================================

func get_current_state() -> GameState:
	return current_state

func is_building_mode() -> bool:
	return current_state == GameState.BUILDING

func is_game_paused() -> bool:
	return current_state == GameState.PAUSED

func get_session_stats() -> Dictionary:
	return session_stats.duplicate()

func get_total_foundations() -> int:
	return total_foundations_built

# ============================================
# Système de sauvegarde (extension future)
# ============================================

func save_game():
	"""Sauvegarder l'état du jeu (à implémenter)"""
	print("💾 Sauvegarde du jeu...")
	# TODO: Implémenter la sauvegarde

func load_game():
	"""Charger l'état du jeu (à implémenter)"""
	print("📁 Chargement du jeu...")
	# TODO: Implémenter le chargement

# ============================================
# Debug et développement
# ============================================

func _process(_delta):
	# Mettre à jour les stats en temps réel (seulement si debug UI visible)
	if debug_ui and debug_ui.visible:
		_update_realtime_stats()

func _update_realtime_stats():
	"""Mettre à jour les statistiques en temps réel"""
	if terrain_manager:
		session_stats.chunks_generated = terrain_manager.loaded_chunks.size()

func debug_info() -> String:
	"""Retourner info de debug pour l'UI"""
	var info = "État: " + _state_to_string(current_state) + "\n"
	info += "Fondations: " + str(total_foundations_built) + "\n"
	if terrain_manager:
		info += "Chunks: " + str(terrain_manager.loaded_chunks.size()) + "\n"
	return info
