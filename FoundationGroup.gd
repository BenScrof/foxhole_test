# ============================================
# FoundationGroup.gd - Classe pour un groupe de fondations connectées
# ============================================

extends RefCounted
class_name FoundationGroup

var foundations: Array[Foundation] = []
var group_id: int

static var next_group_id: int = 0

func _init():
	group_id = next_group_id
	next_group_id += 1

func add_foundation(foundation: Foundation):
	if foundation not in foundations:
		foundations.append(foundation)
		foundation.foundation_destroyed.connect(_on_foundation_destroyed)

func remove_foundation(foundation: Foundation):
	if foundation in foundations:
		foundations.erase(foundation)
		if foundation.foundation_destroyed.is_connected(_on_foundation_destroyed):
			foundation.foundation_destroyed.disconnect(_on_foundation_destroyed)

func _on_foundation_destroyed(foundation: Foundation):
	remove_foundation(foundation)
	
	# Si le groupe devient vide, il devra être supprimé par le gestionnaire
	if foundations.is_empty():
		print("Groupe de fondations ", group_id, " est maintenant vide")

func get_total_foundations() -> int:
	return foundations.size()

func get_bounds() -> AABB:
	if foundations.is_empty():
		return AABB()
	
	var min_pos = foundations[0].global_position
	var max_pos = foundations[0].global_position
	
	for foundation in foundations:
		var pos = foundation.global_position
		min_pos = Vector3(
			min(min_pos.x, pos.x),
			min(min_pos.y, pos.y),
			min(min_pos.z, pos.z)
		)
		max_pos = Vector3(
			max(max_pos.x, pos.x),
			max(max_pos.y, pos.y),
			max(max_pos.z, pos.z)
		)
	
	return AABB(min_pos, max_pos - min_pos)
