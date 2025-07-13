# ============================================
# PlayerController.gd - VERSION AMÉLIORÉE avec meilleure communication terrain
# ============================================

extends CharacterBody3D
class_name Player

# Paramètres de mouvement
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002
@export var max_look_angle: float = 90.0

# Références aux nœuds
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# Variables internes
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var look_rotation: Vector2 = Vector2.ZERO

# Variables pour communication avec le terrain
var last_notified_position: Vector3 = Vector3.ZERO
var position_update_threshold: float = 2.0  # Notifier tous les 2 mètres
var terrain_manager: TerrainManager
var initialization_complete: bool = false

func _ready():
	add_to_group("player")  # ← CRUCIAL pour que les autres systèmes nous trouvent
	print("🚶 === PLAYER CONTROLLER AMÉLIORÉ ===")
	
	# Capturer la souris
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Configurer la collision du joueur
	_setup_collision_shape()
	
	# Trouver le terrain manager
	call_deferred("_find_terrain_manager")

func _setup_collision_shape():
	"""Configurer la forme de collision du joueur"""
	if collision_shape.shape == null:
		var capsule = CapsuleShape3D.new()
		capsule.radius = 0.5
		capsule.height = 1.8
		collision_shape.shape = capsule

func _find_terrain_manager():
	"""Trouver et se connecter au terrain manager"""
	# Attendre quelques frames que tout soit initialisé
	await get_tree().process_frame
	await get_tree().process_frame
	
	terrain_manager = get_tree().get_first_node_in_group("world")
	
	if terrain_manager:
		print("✅ Player: TerrainManager trouvé")
		# Notifier immédiatement notre position
		terrain_manager.update_player_position(global_position)
		last_notified_position = global_position
		initialization_complete = true
		print("🗺️ Position initiale notifiée: ", global_position)
	else:
		print("⚠️ Player: TerrainManager non trouvé!")
		# Réessayer dans 1 seconde
		await get_tree().create_timer(1.0).timeout
		_find_terrain_manager()

func _input(event):
	# Gestion de la rotation de la caméra avec la souris
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_handle_mouse_movement(event.relative)
	
	# Échapper pour libérer/capturer la souris (debug)
	if event.is_action_pressed("ui_cancel"):
		_toggle_mouse_capture()
	
	# F2 pour debug position joueur
	if event.is_action_pressed("ui_select") and event.keycode == KEY_F2:  # F2
		_debug_player_info()

func _toggle_mouse_capture():
	"""Basculer entre capture et libération de la souris"""
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		print("🖱️ Souris libérée")
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		print("🖱️ Souris capturée")

func _handle_mouse_movement(mouse_delta: Vector2):
	"""Gérer la rotation de la caméra avec la souris"""
	# Rotation horizontale (yaw)
	look_rotation.x -= mouse_delta.x * mouse_sensitivity
	
	# Rotation verticale (pitch) avec limitation
	look_rotation.y -= mouse_delta.y * mouse_sensitivity
	look_rotation.y = clamp(look_rotation.y, -deg_to_rad(max_look_angle), deg_to_rad(max_look_angle))
	
	# Appliquer les rotations
	transform.basis = Basis(Vector3.UP, look_rotation.x)
	head.transform.basis = Basis(Vector3.RIGHT, look_rotation.y)

func _physics_process(delta):
	# Ajouter la gravité
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Gérer le saut
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
	
	# Obtenir la direction d'entrée
	var input_dir = _get_input_direction()
	
	# Calculer la direction de mouvement relative à la rotation du joueur
	var direction = Vector3.ZERO
	if input_dir != Vector2.ZERO:
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Appliquer le mouvement
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	# Déplacer le joueur
	move_and_slide()
	
	# Notifier le changement de position si nécessaire
	_check_position_change()

func _get_input_direction() -> Vector2:
	"""Obtenir la direction d'entrée du joueur"""
	var input_dir = Vector2.ZERO
	
	# Gestion des touches de mouvement (ZQSD)
	if Input.is_action_pressed("move_forward"):   # Z
		input_dir.y -= 1
	if Input.is_action_pressed("move_backward"):  # S
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):      # Q
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):     # D
		input_dir.x += 1
	
	return input_dir

func _check_position_change():
	"""Vérifier si on doit notifier le terrain manager d'un changement de position"""
	if not initialization_complete or not terrain_manager:
		return
	
	var current_pos = global_position
	var distance_moved = current_pos.distance_to(last_notified_position)
	
	# Notifier si on a bougé suffisamment ou toutes les secondes
	if distance_moved > position_update_threshold:
		_notify_position_change()
		last_notified_position = current_pos

func _notify_position_change():
	"""Informer le gestionnaire de terrain de notre nouvelle position"""
	if terrain_manager and terrain_manager.has_method("update_player_position"):
		terrain_manager.update_player_position(global_position)

# ============================================
# MÉTHODES PUBLIQUES pour les autres systèmes
# ============================================

func get_player_position() -> Vector3:
	"""Obtenir la position du joueur"""
	return global_position

func get_look_direction() -> Vector3:
	"""Obtenir la direction du regard (utile pour les interactions)"""
	return -camera.global_transform.basis.z.normalized()

func get_current_chunk_position() -> Vector2i:
	"""Obtenir la position du chunk actuel du joueur"""
	if terrain_manager:
		return terrain_manager.player_chunk_pos
	else:
		# Calculer nous-mêmes si le terrain manager n'est pas disponible
		var chunk_size = 16  # Valeur par défaut
		return Vector2i(
			int(floor(global_position.x / chunk_size)),
			int(floor(global_position.z / chunk_size))
		)

func teleport_to_position(new_position: Vector3):
	"""Téléporter le joueur à une nouvelle position"""
	global_position = new_position
	
	# Notifier immédiatement le terrain manager
	if terrain_manager:
		terrain_manager.update_player_position(global_position)
		last_notified_position = global_position
	
	print("🚀 Joueur téléporté à: ", new_position)

# ============================================
# MÉTHODES DE DEBUG
# ============================================

func _debug_player_info():
	"""Afficher des informations de debug sur le joueur"""
	print("=== DEBUG PLAYER ===")
	print("Position: ", global_position)
	print("Chunk: ", get_current_chunk_position())
	print("Vitesse: ", velocity)
	print("Sol: ", is_on_floor())
	print("Terrain Manager: ", "Connecté" if terrain_manager else "Non connecté")
	print("Last notified pos: ", last_notified_position)
	print("Distance depuis dernière notification: ", global_position.distance_to(last_notified_position))
	print("====================")

func force_terrain_update():
	"""Forcer une mise à jour du terrain (debug)"""
	if terrain_manager:
		terrain_manager.update_player_position(global_position)
		last_notified_position = global_position
		print("🔄 Mise à jour terrain forcée")
	else:
		print("⚠️ Pas de terrain manager connecté")

# ============================================
# INTÉGRATION AVEC LE SYSTÈME DE CONSTRUCTION
# ============================================

func get_construction_target_position() -> Vector3:
	"""Obtenir la position cible pour la construction (devant le joueur)"""
	var forward_distance = 3.0
	var look_dir = get_look_direction()
	var target_pos = global_position + look_dir * forward_distance
	
	# Ajuster la hauteur au terrain si possible
	if terrain_manager:
		target_pos.y = terrain_manager.get_terrain_height_at_position(target_pos)
	
	return target_pos

func is_in_construction_range(target_position: Vector3, max_range: float = 5.0) -> bool:
	"""Vérifier si une position est dans la portée de construction"""
	return global_position.distance_to(target_position) <= max_range
