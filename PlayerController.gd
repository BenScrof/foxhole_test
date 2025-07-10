# ============================================
# PlayerController.gd - Contrôleur du joueur
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

func _ready():
	# Capturer la souris
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Configurer la collision du joueur
	if collision_shape.shape == null:
		var capsule = CapsuleShape3D.new()
		capsule.radius = 0.5
		capsule.height = 1.8
		collision_shape.shape = capsule

func _input(event):
	# Gestion de la rotation de la caméra avec la souris
	if event is InputEventMouseMotion:
		_handle_mouse_movement(event.relative)
	
	# Échapper pour libérer la souris (debug)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _handle_mouse_movement(mouse_delta: Vector2):
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
	
	# Obtenir la direction d'entrée (ZQSD)
	var input_dir = Vector2.ZERO
	
	# Z = Avant, S = Arrière, Q = Gauche, D = Droite
	if Input.is_action_pressed("move_forward"):  # Z
		input_dir.y -= 1
	if Input.is_action_pressed("move_backward"): # S
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):     # Q
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):    # D
		input_dir.x += 1
	
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
	
	# Notifier le gestionnaire de terrain de notre position
	_notify_position_change()

func _notify_position_change():
	# Informer le gestionnaire de terrain de notre nouvelle position
	# pour le chargement/déchargement des chunks
	var world = get_tree().get_first_node_in_group("world")
	if world and world.has_method("update_player_position"):
		world.update_player_position(global_position)

# Méthode pour obtenir la position du joueur (utile pour les autres systèmes)
func get_player_position() -> Vector3:
	return global_position

# Méthode pour obtenir la direction du regard (utile pour les interactions)
func get_look_direction() -> Vector3:
	return -camera.global_transform.basis.z.normalized()
