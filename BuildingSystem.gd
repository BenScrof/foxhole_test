# ============================================
# BuildingSystem.gd - Système WFC avec Table de Règles
# ============================================

extends Node3D
class_name BuildingSystem

enum BuildingType {
	MUR_DROIT,
	MUR_COIN,
	MUR_PORTE,
	MUR_FENETRE
}

# Table de règles de connexion WFC
var connection_rules = {
	BuildingType.MUR_DROIT: {
		"north": {
			"can_connect_to": [
				{"building": BuildingType.MUR_DROIT, "face": "south"},
				{"building": BuildingType.MUR_COIN, "face": "south"},
				{"building": BuildingType.MUR_PORTE, "face": "south"},
				{"building": BuildingType.MUR_FENETRE, "face": "south"}
			],
			"connection_type": "wall_solid"
		},
		"south": {
			"can_connect_to": [
				{"building": BuildingType.MUR_DROIT, "face": "north"},
				{"building": BuildingType.MUR_COIN, "face": "north"},
				{"building": BuildingType.MUR_PORTE, "face": "north"},
				{"building": BuildingType.MUR_FENETRE, "face": "north"}
			],
			"connection_type": "wall_solid"
		},
		"east": {
			"can_connect_to": [
				{"building": BuildingType.MUR_DROIT, "face": "west"},
				{"building": BuildingType.MUR_COIN, "face": "west"}
			],
			"connection_type": "wall_solid"
		},
		"west": {
			"can_connect_to": [
				{"building": BuildingType.MUR_DROIT, "face": "east"},
				{"building": BuildingType.MUR_COIN, "face": "east"}
			],
			"connection_type": "wall_solid"
		}
	},
	
	BuildingType.MUR_COIN: {
		"north": {
			"can_connect_to": [
				{"building": BuildingType.MUR_DROIT, "face": "south"},
				{"building": BuildingType.MUR_PORTE, "face": "south"},
				{"building": BuildingType.MUR_FENETRE, "face": "south"}
			],
			"connection_type": "wall_solid"
		},
		"east": {
			"can_connect_to": [
				{"building": BuildingType.MUR_DROIT, "face": "west"},
				{"building": BuildingType.MUR_PORTE, "face": "west"},
				{"building": BuildingType.MUR_FENETRE, "face": "west"}
			],
			"connection_type": "wall_solid"
		}
	},
	
	BuildingType.MUR_PORTE: {
		"north": {
			"can_connect_to": [
				{"building": BuildingType.MUR_DROIT, "face": "south"},
				{"building": BuildingType.MUR_COIN, "face": "south"}
				# Pas de connexion MUR_PORTE -> MUR_PORTE (éviter double porte)
			],
			"connection_type": "door_opening"
		},
		"south": {
			"can_connect_to": [
				{"building": BuildingType.MUR_DROIT, "face": "north"},
				{"building": BuildingType.MUR_COIN, "face": "north"}
			],
			"connection_type": "door_opening"
		}
	},
	
	BuildingType.MUR_FENETRE: {
		"north": {
			"can_connect_to": [
				{"building": BuildingType.MUR_DROIT, "face": "south"},
				{"building": BuildingType.MUR_COIN, "face": "south"},
				{"building": BuildingType.MUR_FENETRE, "face": "south"}
			],
			"connection_type": "window"
		},
		"south": {
			"can_connect_to": [
				{"building": BuildingType.MUR_DROIT, "face": "north"},
				{"building": BuildingType.MUR_COIN, "face": "north"},
				{"building": BuildingType.MUR_FENETRE, "face": "north"}
			],
			"connection_type": "window"
		}
	}
}

# Données des bâtiments
var building_data: Dictionary = {
	BuildingType.MUR_DROIT: {
		"name": "Mur Droit",
		"scene_path": "res://assets/models/mur_droit.tscn",
		"icon": "🧱",
		"size": Vector3(0.1, 2, 1)
	},
	BuildingType.MUR_COIN: {
		"name": "Mur Coin", 
		"scene_path": "res://assets/models/mur_coin.tscn",
		"icon": "📐",
		"size": Vector3(1.1, 2, 1.1)
	},
	BuildingType.MUR_PORTE: {
		"name": "Mur Porte",
		"scene_path": "res://assets/models/mur_porte.tscn",
		"icon": "🚪",
		"size": Vector3(0.1, 2, 1)
	},
	BuildingType.MUR_FENETRE: {
		"name": "Mur Fenêtre",
		"scene_path": "res://assets/models/mur_fenetre.tscn", 
		"icon": "🪟",
		"size": Vector3(0.1, 2, 1)
	}
}

var construction_manager: ConstructionManager
var placed_buildings: Array[Dictionary] = []

func _ready():
	add_to_group("building_system")
	construction_manager = get_tree().get_first_node_in_group("construction_manager")

# ============================================
# Système WFC - Validation de Règles
# ============================================

func can_buildings_connect(building1_type: BuildingType, face1: String, 
						   building2_type: BuildingType, face2: String) -> bool:
	"""Vérifie si deux bâtiments peuvent se connecter selon les règles WFC"""
	
	var rules1 = connection_rules.get(building1_type, {})
	var face_rules = rules1.get(face1, {})
	var allowed_connections = face_rules.get("can_connect_to", [])
	
	for connection in allowed_connections:
		if connection.building == building2_type and connection.face == face2:
			return true
	
	return false

func get_opposite_direction(direction: String) -> String:
	"""Retourne la direction opposée"""
	match direction:
		"north": return "south"
		"south": return "north"
		"east": return "west"
		"west": return "east"
		"up": return "down"
		"down": return "up"
		_: return ""

func get_direction_vector(direction: String) -> Vector3:
	"""Convertit direction en Vector3"""
	match direction:
		"north": return Vector3.FORWARD   # +Z
		"south": return Vector3.BACK      # -Z  
		"east": return Vector3.RIGHT      # +X
		"west": return Vector3.LEFT       # -X
		"up": return Vector3.UP           # +Y
		"down": return Vector3.DOWN       # -Y
		_: return Vector3.ZERO

# ============================================
# Détection des SnapFaces
# ============================================

func get_building_snapfaces(building_node: Node3D) -> Dictionary:
	"""Récupère toutes les SnapFaces d'un bâtiment"""
	var snapfaces = {}
	
	for child in building_node.get_children():
		if child.name.begins_with("SnapFace_") and child is Area3D:
			var direction = child.name.replace("SnapFace_", "")
			snapfaces[direction] = {
				"area": child,
				"position": child.global_position,
				"direction": direction,
				"normal": get_direction_vector(direction)
			}
	
	return snapfaces

func find_nearby_snapfaces(target_pos: Vector3, search_radius: float = 2.0) -> Array:
	var nearby = []
	
	print("🔍 Recherche SnapFaces près de: ", target_pos)
	print("🔍 Bâtiments placés: ", placed_buildings.size())
	
	for building_data in placed_buildings:
		if not building_data.node or not is_instance_valid(building_data.node):
			continue
		
		print("🔍 Vérification bâtiment: ", building_data.node.name)
		var snapfaces = get_building_snapfaces(building_data.node)
		print("🔍 SnapFaces trouvées: ", snapfaces.keys())
		
		for direction in snapfaces:
			var snapface = snapfaces[direction]
			var distance = target_pos.distance_to(snapface.position)
			print("🔍 ", direction, " à distance: ", distance, " position: ", snapface.position)
			
			if distance <= search_radius:
				nearby.append({
					"snapface": snapface,
					"building": building_data.node,
					"building_type": building_data.type,
					"direction": direction,
					"distance": distance
				})
				print("✅ SnapFace ajoutée: ", direction)
	
	print("🔍 Total SnapFaces proches: ", nearby.size())
	return nearby

# ============================================
# Validation de Placement
# ============================================

func can_place_building(building_type: BuildingType, position: Vector3, rotation: float = 0.0) -> Dictionary:
	"""Validation complète WFC pour placement"""
	var result = {
		"valid": false,
		"reason": "",
		"snap_data": {}
	}
	
	# 1. Vérifier si on est sur une fondation
	if not _is_on_foundation(position):
		result.reason = "Doit être sur une fondation"
		return result
	
	# 2. Vérifier les collisions
	if _has_building_collision(building_type, position, rotation):
		result.reason = "Collision avec autre bâtiment"
		return result
	
	# 3. Chercher snap WFC valide
	var snap_info = _find_valid_wfc_snap(building_type, position, rotation)
	if snap_info.has("position"):
		result.snap_data = snap_info
	
	# 4. Valider les règles WFC
	if not _validate_all_wfc_connections(building_type, position, rotation):
		result.reason = "Violation des règles WFC"
		return result
	
	result.valid = true
	return result

func _find_valid_wfc_snap(building_type: BuildingType, target_pos: Vector3, rotation: float) -> Dictionary:
	"""Trouve un snap valide selon les règles WFC"""
	var nearby = find_nearby_snapfaces(target_pos)
	var closest_snap = {}
	var min_distance = 2.0
	
	for nearby_snap in nearby:
		var other_building_type = nearby_snap.building_type
		var other_face = nearby_snap.direction
		var my_face = get_opposite_direction(other_face)
		
		# Vérifier règles WFC
		if can_buildings_connect(building_type, my_face, other_building_type, other_face):
			if nearby_snap.distance < min_distance:
				closest_snap = {
					"position": nearby_snap.snapface.position,
					"building": nearby_snap.building,
					"snap_name": other_face,
					"my_face": my_face,
					"other_type": other_building_type
				}
				min_distance = nearby_snap.distance
	
	return closest_snap

func _validate_all_wfc_connections(building_type: BuildingType, position: Vector3, rotation: float) -> bool:
	"""Valide que toutes les connexions respectent WFC"""
	var theoretical_snapfaces = _get_theoretical_snapfaces(building_type, position, rotation)
	
	for direction in theoretical_snapfaces:
		var my_snapface = theoretical_snapfaces[direction]
		var nearby = find_nearby_snapfaces(my_snapface.position, 0.5)
		
		for nearby_snap in nearby:
			var other_building_type = nearby_snap.building_type
			var other_face = nearby_snap.direction
			
			# Si on est très proche, on DOIT être compatible
			if nearby_snap.distance < 0.3:
				if not can_buildings_connect(building_type, direction, other_building_type, other_face):
					print("❌ WFC violation: ", building_type, ":", direction, " -> ", other_building_type, ":", other_face)
					return false
	
	return true

func _get_theoretical_snapfaces(building_type: BuildingType, position: Vector3, rotation: float) -> Dictionary:
	"""Calcule où seraient les SnapFaces si on plaçait le bâtiment"""
	var snapfaces = {}
	var rules = connection_rules.get(building_type, {})
	
	for direction in rules:
		var offset = get_direction_vector(direction)
		var size = building_data[building_type].size
		
		# Ajuster offset selon la taille du bâtiment
		match direction:
			"north": offset *= size.z / 2
			"south": offset *= size.z / 2
			"east": offset *= size.x / 2
			"west": offset *= size.x / 2
		
		# Appliquer rotation
		offset = offset.rotated(Vector3.UP, deg_to_rad(rotation))
		
		snapfaces[direction] = {
			"position": position + offset,
			"direction": direction
		}
	
	return snapfaces

# ============================================
# Fonctions utilitaires existantes
# ============================================

func _is_on_foundation(position: Vector3) -> bool:
	if not construction_manager:
		return false
	
	for foundation_data in construction_manager.placed_foundations:
		if not foundation_data.node or not is_instance_valid(foundation_data.node):
			continue
		
		var foundation_pos = foundation_data.node.global_position
		var foundation_size = construction_manager.foundation_size
		
		var x_diff = abs(position.x - foundation_pos.x)
		var z_diff = abs(position.z - foundation_pos.z)
		var y_diff = abs(position.y - foundation_pos.y)
		
		if x_diff <= foundation_size/2 and z_diff <= foundation_size/2 and y_diff <= 0.5:
			return true
	
	return false

func _has_building_collision(building_type: BuildingType, position: Vector3, rotation: float) -> bool:
	var building_size = building_data[building_type].size
	
	for building in placed_buildings:
		if not building.node or not is_instance_valid(building.node):
			continue
		
		var other_pos = building.node.global_position
		var distance = position.distance_to(other_pos)
		
		var min_distance = (building_size.length() + 1.0) / 3.0
		
		if distance < min_distance:
			return true
	
	return false

# ============================================
# Placement de bâtiments
# ============================================

func place_building(building_type: BuildingType, position: Vector3, rotation: float = 0.0) -> bool:
	var validation = can_place_building(building_type, position, rotation)
	
	if not validation.valid:
		print("❌ Placement impossible: ", validation.reason)
		return false
	
	var data = building_data[building_type]
	var scene_path = data.scene_path
	
	if not ResourceLoader.exists(scene_path):
		print("❌ Scene non trouvée: ", scene_path)
		return false
	
	var scene = load(scene_path)
	var building_instance = scene.instantiate()
	
	building_instance.name = data.name + "_" + str(placed_buildings.size())
	building_instance.add_to_group("buildings")
	
	var final_position = position
	if validation.snap_data.has("position"):
		final_position = validation.snap_data.position
	
	get_tree().root.add_child(building_instance)
	building_instance.global_position = final_position
	building_instance.rotation_degrees.y = rotation
	
	placed_buildings.append({
		"node": building_instance,
		"type": building_type,
		"position": final_position,
		"rotation": rotation
	})
	
	print("✅ ", data.name, " placé! Total: ", placed_buildings.size())
	return true

# ============================================
# Interface publique
# ============================================

func get_building_count() -> int:
	return placed_buildings.size()

func clear_all_buildings():
	for building in placed_buildings:
		if building.node and is_instance_valid(building.node):
			building.node.queue_free()
	placed_buildings.clear()

func get_building_types_for_wheel() -> Array[Dictionary]:
	var wheel_data = []
	for building_type in building_data:
		var data = building_data[building_type]
		wheel_data.append({
			"type": building_type,
			"name": data.name,
			"icon": data.icon,
			"scene_path": data.scene_path,
			"category": "building"
		})
	return wheel_data
