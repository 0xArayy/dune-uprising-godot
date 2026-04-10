extends RefCounted
class_name ConflictResolutionRules

const RuleContractScript = preload("res://scripts/domain/rule_contract.gd")

func build_power_snapshots(players: Array, conflict_zone: Dictionary) -> Dictionary:
	var power_by_player: Dictionary = {}
	var participant_power_by_player: Dictionary = {}
	for p in players:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var pid := str(p.get("id", ""))
		if pid == "":
			continue
		var zone: Dictionary = {}
		if conflict_zone.has(pid) and typeof(conflict_zone[pid]) == TYPE_DICTIONARY:
			zone = conflict_zone[pid]
		var total_power := RuleContractScript.compute_combat_power(zone)
		power_by_player[pid] = total_power
		if int(zone.get("troops", 0)) > 0 or int(zone.get("sandworms", 0)) > 0:
			participant_power_by_player[pid] = total_power
		if conflict_zone.has(pid) and typeof(conflict_zone[pid]) == TYPE_DICTIONARY:
			conflict_zone[pid]["totalPower"] = total_power
	return {
		"powerByPlayer": power_by_player,
		"participantPowerByPlayer": participant_power_by_player
	}

func compute_ranking_groups(power_by_player: Dictionary) -> Array:
	var remaining: Array = []
	for pid in power_by_player.keys():
		remaining.append(str(pid))
	var groups: Array = []
	while not remaining.is_empty():
		var max_power := -2147483648
		var group: Array = []
		for pid in remaining:
			var pwr := int(power_by_player.get(pid, 0))
			if pwr > max_power:
				max_power = pwr
				group = [str(pid)]
			elif pwr == max_power:
				group.append(str(pid))
		groups.append(group)
		var next_remaining: Array = []
		for pid in remaining:
			if not group.has(str(pid)):
				next_remaining.append(str(pid))
		remaining = next_remaining
	return groups
