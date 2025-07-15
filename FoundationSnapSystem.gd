# ============================================
# FoundationSnapSystem.gd - VERSION OPTIMISÉE avec SnapPoints existants
# ============================================
# Utilise les SnapPoints déjà présents dans vos scènes

extends Node3D
class_name FoundationSnapSystem

# Configuration du snap
@export var snap_distance: float = 2.5        # Distance maximale pour snap
@export var snap_precision: float = 0.1       # Précision d'alignement
@export var show_snap_helpers: bool = true    # Debug visuel

# Types de connexions
enum SnapType {
	SIDE_TO_SIDE,       # Côté à côté (fondation standard)
	ENTRY_TO_SIDE,      # Entrée de rampe vers côté de fondation
	TOP_CONNECTION,     # Connexion sur le dessus
	CORNER_CONNECTION   # Connexion en coin
}

# Structure pour les infos de snap
class SnapInfo:
	var target_foundation: Node3D
	var target_snap_point: Node3D
	var snap_position: Vector3
	var snap_rotation: float
	var snap_type: SnapType
	var distance: float

# Variables internes
var nearby_foundations: Array[Node3D] = []
var current_snap_info: SnapInfo = null

func _ready():
	print("🧲 Système de snap avec SnapPoints initialisé")

func find_snap_position(preview_position: Vector3, preview_rotation: float, foundation_type: FoundationSelectionWheel.FoundationType) -> SnapInfo:
	"""Trouver la meilleure position de snap en utilisant les SnapPoints"""
	
	current_snap_info = null
	nearby_foundations.clear()
	
	# Trouver les fondations proches
	_find_nearby_foundations(preview_position)
	
	if nearby_foundations.is_empty():
		return null
	
	print("🔍 Analyse snap pour ", foundation_type, " - ", nearby_foundations.size(), " fondations proches")
	
	# Analyser chaque fondation pour trouver le meilleur snap
	var best_snap: SnapInfo = null
	var best_distance: float = snap_distance
	
	for foundation in nearby_foundations:
		var snap_info = _analyze_foundation_snap_points(foundation, preview_position, preview_rotation, foundation_type)
		
		if snap_info and snap_info.distance < best_distance:
			best_snap = snap_info
			best_distance = snap_info.distance
	
	current_snap_info = best_snap
	return best_snap

func _find_nearby_foundations(position: Vector3):
	"""Trouver toutes les fondations dans le rayon de snap"""
	var all_foundations = get_tree().get_nodes_in_group("foundations")
	
	for foundation in all_foundations:
		if foundation is Node3D:
			var distance = position.distance_to(foundation.global_position)
			if distance <= snap_distance * 2:  # Zone élargie pour les SnapPoints
				nearby_foundations.append(foundation)

func _analyze_foundation_snap_points(target: Node3D, pos: Vector3, rot: float, type: FoundationSelectionWheel.FoundationType) -> SnapInfo:
	"""Analyser les SnapPoints d'une fondation pour trouver le meilleur snap"""
	
	# Obtenir tous les SnapPoints de la fondation cible
	var target_snap_points = _get_snap_points(target)
	
	if target_snap_points.is_empty():
		print("⚠️ Aucun SnapPoint trouvé sur ", target.name)
		return null
	
	print("🎯 Analyse ", target_snap_points.size(), " SnapPoints sur ", target.name)
	
	# Tester chaque SnapPoint
	var best_snap: SnapInfo = null
	var best_distance: float = snap_distance
	
	for snap_point in target_snap_points:
		var snap_info = _test_snap_point_connection(target, snap_point, pos, rot, type)
		
		if snap_info and snap_info.distance < best_distance:
			best_snap = snap_info
			best_distance = snap_info.distance
			print("  ✅ Meilleur snap: ", snap_point.name, " distance=", snap_info.distance)
	
	return best_snap

func _get_snap_points(foundation: Node3D) -> Array[Node3D]:
	"""Obtenir tous les SnapPoints d'une fondation"""
	var snap_points: Array[Node3D] = []
	
	for child in foundation.get_children():
		if child.name.begins_with("SnapPoint_"):
			snap_points.append(child)
	
	return snap_points

func _test_snap_point_connection(target: Node3D, snap_point: Node3D, pos: Vector3, rot: float, type: FoundationSelectionWheel.FoundationType) -> SnapInfo:
	"""Tester la connexion avec un SnapPoint spécifique"""
	
	# Position globale du SnapPoint
	var snap_world_pos = target.to_global(snap_point.position)
	
	# Déterminer le type de connexion basé sur les noms
	var snap_type = _determine_snap_type_from_names(snap_point.name, type)
	
	# Calculer où devrait être notre fondation pour se connecter
	var connection_offset = _get_connection_offset(snap_point.name, type)
	var desired_pos = snap_world_pos + connection_offset
	
	# Calculer la rotation appropriée
	var desired_rotation = _calculate_rotation_for_snap_point(snap_point.name, target.rotation.y, type)
	
	# Vérifier la distance
	var distance = pos.distance_to(desired_pos)
	
	if distance > snap_distance:
		return null
	
	# Créer les infos de snap
	var snap_info = SnapInfo.new()
	snap_info.target_foundation = target
	snap_info.target_snap_point = snap_point
	snap_info.snap_position = desired_pos
	snap_info.snap_rotation = desired_rotation
	snap_info.snap_type = snap_type
	snap_info.distance = distance
	
	print("  🔗 Snap possible: ", snap_point.name, " distance=", distance, " type=", snap_type)
	
	return snap_info

func _determine_snap_type_from_names(snap_point_name: String, foundation_type: FoundationSelectionWheel.FoundationType) -> SnapType:
	"""Déterminer le type de snap basé sur les noms des SnapPoints"""
	
	# Rampe vers fondation
	if foundation_type == FoundationSelectionWheel.FoundationType.RAMPE:
		if "Side_" in snap_point_name:
			return SnapType.ENTRY_TO_SIDE
		elif "Top" in snap_point_name:
			return SnapType.TOP_CONNECTION
	
	# Fondation vers rampe ou fondation
	elif foundation_type == FoundationSelectionWheel.FoundationType.NORMAL:
		if "Side_" in snap_point_name:
			return SnapType.SIDE_TO_SIDE
		elif "Entry" in snap_point_name:
			return SnapType.ENTRY_TO_SIDE
		elif "Top" in snap_point_name:
			return SnapType.TOP_CONNECTION
	
	# Coin rampe
	elif foundation_type == FoundationSelectionWheel.FoundationType.COIN_RAMPE:
		return SnapType.CORNER_CONNECTION
	
	return SnapType.SIDE_TO_SIDE

func _get_connection_offset(snap_point_name: String, foundation_type: FoundationSelectionWheel.FoundationType) -> Vector3:
	"""Calculer l'offset pour la connexion selon le type de SnapPoint"""
	
	# Analyser le nom du SnapPoint pour déterminer la direction
	var offset = Vector3.ZERO
	
	if "North" in snap_point_name:
		offset = Vector3(0, 0, -2)  # Se placer au nord (vers -Z)
	elif "South" in snap_point_name:
		offset = Vector3(0, 0, 2)   # Se placer au sud (vers +Z)
	elif "East" in snap_point_name:
		offset = Vector3(-2, 0, 0)  # Se placer à l'est (vers -X)
	elif "West" in snap_point_name:
		offset = Vector3(2, 0, 0)   # Se placer à l'ouest (vers +X)
	elif "Entry" in snap_point_name:
		# Pour l'entrée de rampe, se connecter selon le type
		if foundation_type == FoundationSelectionWheel.FoundationType.NORMAL:
			offset = Vector3(-2, 0, 0)  # Fondation se place devant l'entrée
		else:
			offset = Vector3(2, 0, 0)   # Autre élément derrière l'entrée
	elif "Top" in snap_point_name:
		offset = Vector3(0, 0.5, 0)  # Se placer au-dessus
	
	return offset

func _calculate_rotation_for_snap_point(snap_point_name: String, target_rotation: float, foundation_type: FoundationSelectionWheel.FoundationType) -> float:
	"""Calculer la rotation appropriée pour le snap"""
	
	var base_rotation = target_rotation
	
	# Ajustements selon le SnapPoint
	if "North" in snap_point_name:
		return base_rotation + PI  # Faire face au sud
	elif "South" in snap_point_name:
		return base_rotation  # Faire face au nord
	elif "East" in snap_point_name:
		return base_rotation + PI/2  # Faire face à l'ouest
	elif "West" in snap_point_name:
		return base_rotation - PI/2  # Faire face à l'est
	elif "Entry" in snap_point_name:
		# Rampe : orienter selon la logique de connexion
		if foundation_type == FoundationSelectionWheel.FoundationType.RAMPE:
			return base_rotation  # Rampe monte dans la même direction
		else:
			return base_rotation + PI  # Fondation fait face à la rampe
	
	return base_rotation

# ============================================
# MÉTHODES PUBLIQUES
# ============================================

func has_snap() -> bool:
	"""Vérifier si un snap est disponible"""
	return current_snap_info != null

func get_snap_position() -> Vector3:
	"""Obtenir la position de snap"""
	if current_snap_info:
		return current_snap_info.snap_position
	return Vector3.ZERO

func get_snap_rotation() -> float:
	"""Obtenir la rotation de snap"""
	if current_snap_info:
		return current_snap_info.snap_rotation
	return 0.0

func get_snap_type() -> SnapType:
	"""Obtenir le type de snap"""
	if current_snap_info:
		return current_snap_info.snap_type
	return SnapType.SIDE_TO_SIDE

func get_snap_info_text() -> String:
	"""Obtenir une description textuelle du snap actuel"""
	if not current_snap_info:
		return "Aucun snap"
	
	var target_name = current_snap_info.target_foundation.name
	var snap_point_name = current_snap_info.target_snap_point.name
	var type_name = _get_snap_type_name(current_snap_info.snap_type)
	
	return type_name + " → " + target_name + " (" + snap_point_name + ")"

func _get_snap_type_name(snap_type: SnapType) -> String:
	"""Obtenir le nom d'un type de snap"""
	match snap_type:
		SnapType.SIDE_TO_SIDE:
			return "Côté à côté"
		SnapType.ENTRY_TO_SIDE:
			return "Entrée → Côté"
		SnapType.TOP_CONNECTION:
			return "Connexion dessus"
		SnapType.CORNER_CONNECTION:
			return "Connexion coin"
		_:
			return "Inconnu"

func clear_snap():
	"""Effacer les informations de snap"""
	current_snap_info = null
	nearby_foundations.clear()

# ============================================
# DEBUG ET VISUALISATION
# ============================================

func debug_snap_points():
	"""Afficher les SnapPoints de toutes les fondations (debug)"""
	print("🔍 === DEBUG SNAP POINTS ===")
	
	var all_foundations = get_tree().get_nodes_in_group("foundations")
	
	for foundation in all_foundations:
		print("📍 Fondation: ", foundation.name)
		var snap_points = _get_snap_points(foundation)
		
		for snap_point in snap_points:
			var world_pos = foundation.to_global(snap_point.position)
			print("  • ", snap_point.name, " → ", snap_point.position, " (global: ", world_pos, ")")
	
	print("==============================")

func get_all_snap_points_in_range(position: Vector3, range: float) -> Array:
	"""Obtenir tous les SnapPoints dans un rayon donné (pour debug visuel)"""
	var points_in_range = []
	
	var all_foundations = get_tree().get_nodes_in_group("foundations")
	
	for foundation in all_foundations:
		var snap_points = _get_snap_points(foundation)
		
		for snap_point in snap_points:
			var world_pos = foundation.to_global(snap_point.position)
			if position.distance_to(world_pos) <= range:
				points_in_range.append({
					"foundation": foundation,
					"snap_point": snap_point,
					"world_position": world_pos
				})
	
	return points_in_range
