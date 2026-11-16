extends RefCounted
class_name WorldSaveData

const FORMAT_VERSION: int = 1


static func create_new(world_id: String, world_name: String, seed: int) -> Dictionary:
	var now: String = Time.get_datetime_string_from_system(true)

	return {
		"format_version": FORMAT_VERSION,

		"world": {
			"id": world_id,
			"name": world_name,
			"created_at": now,
			"updated_at": now
		},

		"generation": {
			"seed": seed
		},

		"terrain": {
			"removed_blocks": [],
			"placed_blocks": [],
			"placed_objects": []
		},

		"player": {},

		"quests": {
			"active_quest_id": "",
			"quantities": [],
			"completed_quest_ids": []
		}
	}

static func cells_to_json(cells: Array) -> Array:
	var result: Array = []

	for cell in cells:
		result.append([cell.x, cell.y])

	return result
