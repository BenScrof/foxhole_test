# ============================================
# DebugUI.gd - Interface de debug avec F1 (VERSION PERSONNALISABLE)
# ============================================
# Script pour scenes/UI/DebugUI.tscn

extends Control
class_name DebugUI

# ============================================
# PARAMÈTRES PERSONNALISABLES (modifiables dans l'inspecteur)
# ============================================
@export_group("Apparence")
@export var debug_font_size: int = 18      # Réduit pour que ça tienne mieux
@export var debug_width: float = 0.4       # Plus large pour éviter les coupures
@export var debug_height: float = 0.3      # Ajusté
@export var debug_padding: int = 15        # Réduit pour plus d'espace texte
@export var debug_separation: int = 8      # Moins d'espace entre lignes
@export var debug_transparency: float = 0.8

@export_group("Style")
@export var border_color: Color = Color(0.2, 0.8, 1.0)
@export var background_color: Color = Color(0, 0, 0, 0.8)
@export var border_width: int = 2          # Plus fin

# Références aux labels (structure correcte)
@onready var fps_label: Label = $VBox/FPSLabel
@onready var chunks_label: Label = $VBox/ChunksLabel
@onready var player_pos_label: Label = $VBox/PlayerPosLabel
@onready var player_chunk_label: Label = $VBox/PlayerChunkLabel
@onready var memory_label: Label = $VBox/MemoryLabel

# Références aux managers
var terrain_manager: TerrainManager
var player: Player

# État d'affichage
var is_visible: bool = false

func _ready():
	# Masquer par défaut
	visible = false
	
	# CORRECTION : DÉSACTIVER l'autowrap pour éviter les retours à la ligne
	fps_label.autowrap_mode = TextServer.AUTOWRAP_OFF  # ← CRUCIAL
	chunks_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	player_pos_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	player_chunk_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	memory_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	
	# Permettre au texte de déborder si nécessaire
	fps_label.clip_contents = false
	chunks_label.clip_contents = false
	player_pos_label.clip_contents = false
	player_chunk_label.clip_contents = false
	memory_label.clip_contents = false
	
	# Trouver les références
	call_deferred("_find_references")
	
	# Configurer l'interface
	_setup_ui()

func _find_references():
	# Attendre que la scène soit prête
	await get_tree().process_frame
	await get_tree().process_frame
	
	terrain_manager = get_tree().get_first_node_in_group("world")
	player = get_tree().get_first_node_in_group("player")
	
	if terrain_manager:
		print("✅ DebugUI: TerrainManager trouvé")
	else:
		print("⚠️ DebugUI: TerrainManager non trouvé dans groupe 'world'")
	
	if player:
		print("✅ DebugUI: Player trouvé")
	else:
		print("⚠️ DebugUI: Player non trouvé dans groupe 'player'")

func _setup_ui():
	# UTILISATION DES PARAMÈTRES PERSONNALISABLES  
	anchor_left = 0.02
	anchor_top = 0.02
	anchor_right = debug_width      # ← UTILISE LA VARIABLE
	anchor_bottom = debug_height    # ← UTILISE LA VARIABLE
	
	# Configuration du VBox pour un meilleur espacement
	var vbox = $VBox
	vbox.add_theme_constant_override("separation", debug_separation)  # ← UTILISE LA VARIABLE
	
	# Style de fond avec paramètres personnalisables
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = background_color  # ← UTILISE LA VARIABLE
	style_box.border_width_left = border_width
	style_box.border_width_right = border_width
	style_box.border_width_top = border_width
	style_box.border_width_bottom = border_width
	style_box.border_color = border_color  # ← UTILISE LA VARIABLE
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	
	# Padding interne avec paramètres
	style_box.content_margin_left = debug_padding     # ← UTILISE LA VARIABLE
	style_box.content_margin_right = debug_padding    # ← UTILISE LA VARIABLE
	style_box.content_margin_top = debug_padding      # ← UTILISE LA VARIABLE
	style_box.content_margin_bottom = debug_padding   # ← UTILISE LA VARIABLE
	
	# Appliquer le style
	add_theme_stylebox_override("panel", style_box)
	
	# CONFIGURATION DES LABELS pour éviter les coupures
	for label in [fps_label, chunks_label, player_pos_label, player_chunk_label, memory_label]:
		# Taille de police
		label.add_theme_font_size_override("font_size", debug_font_size)  # ← UTILISE LA VARIABLE
		
		# CRUCIAL : Alignement et contraintes pour tout sur une ligne
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Permettre au label de s'étendre horizontalement
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# S'assurer qu'il n'y a pas de largeur minimale qui force les retours à la ligne
		label.custom_minimum_size = Vector2(0, 0)

func _input(event):
	# Toggle avec F1
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		toggle_debug_ui()

func toggle_debug_ui():
	is_visible = !is_visible
	visible = is_visible
	
	if is_visible:
		print("🔍 Debug UI activé")
	else:
		print("🔍 Debug UI désactivé")

func _process(_delta):
	# Mettre à jour seulement si visible
	if not visible:
		return
	
	_update_debug_info()

func _update_debug_info():
	# FPS avec indicateur simple (texte plus compact)
	var fps = Engine.get_frames_per_second()
	if fps >= 50:
		fps_label.text = "🎯 FPS: " + str(fps) + " ✅"
	elif fps >= 30:
		fps_label.text = "🎯 FPS: " + str(fps) + " ⚠️"
	else:
		fps_label.text = "🎯 FPS: " + str(fps) + " ❌"
	
	# Chunks chargés (texte plus court)
	var chunks_count = 0
	if terrain_manager and terrain_manager.loaded_chunks:
		chunks_count = terrain_manager.loaded_chunks.size()
	
	chunks_label.text = "📦 Chunks: " + str(chunks_count)
	
	# Position du joueur (format plus compact)
	if player:
		var pos = player.global_position
		player_pos_label.text = "🚶 Pos: (" + str(int(pos.x)) + "," + str(int(pos.y)) + "," + str(int(pos.z)) + ")"
		
		# Chunk actuel du joueur (format plus compact)
		if terrain_manager and terrain_manager.player_chunk_pos:
			var chunk_pos = terrain_manager.player_chunk_pos
			player_chunk_label.text = "🗺️ Chunk: (" + str(chunk_pos.x) + "," + str(chunk_pos.y) + ")"
		else:
			player_chunk_label.text = "🗺️ Chunk: N/A"
	else:
		player_pos_label.text = "🚶 Pos: N/A"
		player_chunk_label.text = "🗺️ Chunk: N/A"
	
	# Utilisation mémoire (format plus compact)
	var memory_usage = OS.get_static_memory_usage()
	var memory_mb = memory_usage / (1024 * 1024)
	memory_label.text = "💾 RAM: " + str(int(memory_mb)) + "MB"

# ============================================
# Méthodes utilitaires pour d'autres systèmes
# ============================================

func add_debug_info(key: String, value: String, color: String = "white"):
	"""Permet aux autres systèmes d'ajouter des infos de debug"""
	# Cette méthode peut être étendue pour des infos personnalisées
	pass

func log_debug(message: String):
	"""Log une information de debug"""
	print("🔍 DEBUG: ", message)
