extends Node

const SAVE_DIRECTORY: String = "user://Worlds"

var current_world: Dictionary = {}

func _ready() -> void:
	var error: Error = ensure_directory()

	if error != OK:
		push_error("Impossible de créer le dossier des sauvegardes : %s" % error)


func ensure_directory() -> Error:
	return DirAccess.make_dir_recursive_absolute(SAVE_DIRECTORY)


func is_valid_world_id(world_id: String) -> bool:
	if world_id.is_empty():
		return false

	for character in world_id:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-":
			return false

	return true


func get_save_path(world_id: String) -> String:
	return SAVE_DIRECTORY.path_join(world_id + ".json")

func get_saved_quest_percentage(quest_data: Dictionary) -> int:
	var completed_ids: Array = quest_data.get("completed_quest_ids", [])
	var counted_ids: Dictionary = {}
	var total: int = 0
	var completed: int = 0

	for quest in Quests.quests:
		if quest == null or quest.id == &"":
			continue

		var quest_id: String = String(quest.id)

		if counted_ids.has(quest_id):
			continue

		counted_ids[quest_id] = true
		total += 1

		if quest_id in completed_ids:
			completed += 1

	if total == 0:
		return 0

	return roundi(float(completed) / float(total) * 100.0)

func save_world(data: Dictionary) -> Error:
	var world: Variant = data.get("world")

	if not world is Dictionary:
		return ERR_INVALID_DATA

	var world_id: Variant = world.get("id")

	if not world_id is String:
		return ERR_INVALID_DATA

	if not is_valid_world_id(world_id):
		return ERR_INVALID_PARAMETER

	var error: Error = ensure_directory()

	if error != OK:
		return error

	var save_path: String = get_save_path(world_id)
	var temporary_path: String = save_path + ".tmp"
	var backup_path: String = save_path + ".bak"

	var snapshot: Dictionary = data.duplicate(true)
	snapshot["world"]["updated_at"] = Time.get_datetime_string_from_system(true)

	var file := FileAccess.open(temporary_path, FileAccess.WRITE)

	if file == null:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(snapshot, "\t"))
	file.flush()
	error = file.get_error()
	file.close()

	if error != OK:
		return error

	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(backup_path):
			error = DirAccess.remove_absolute(backup_path)

			if error != OK:
				return error

		error = DirAccess.rename_absolute(save_path, backup_path)

		if error != OK:
			return error

	error = DirAccess.rename_absolute(temporary_path, save_path)

	if error != OK:
		if FileAccess.file_exists(backup_path):
			var restore_error: Error = DirAccess.rename_absolute(backup_path, save_path)

			if restore_error != OK:
				push_error("La sauvegarde précédente reste disponible dans : " + backup_path)

		return error

	data["world"]["updated_at"] = snapshot["world"]["updated_at"]
	return OK

func list_worlds() -> Array[Dictionary]:
	var worlds: Array[Dictionary] = []
	var world_ids: Dictionary = {}
	var directory := DirAccess.open(SAVE_DIRECTORY)

	if directory == null:
		push_error("Impossible d'ouvrir le dossier des mondes.")
		return worlds

	for file_name in directory.get_files():
		var world_id: String = ""

		if file_name.ends_with(".json"):
			world_id = file_name.trim_suffix(".json")
		elif file_name.ends_with(".json.bak"):
			world_id = file_name.trim_suffix(".json.bak")
		else:
			continue

		if is_valid_world_id(world_id):
			world_ids[world_id] = true

	for world_id: String in world_ids:
		var data: Dictionary = load_world(world_id)

		if data.is_empty():
			continue

		var world: Dictionary = data["world"]

		worlds.append({
			"id": world_id,
			"name": String(world.get("name", "Unnamed world")),
			"updated_at": String(world.get("updated_at", "")),
			"quest_percentage": get_saved_quest_percentage(data["quests"])
		})

	worlds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["updated_at"]) > String(b["updated_at"])
	)

	return worlds

func load_world(world_id: String) -> Dictionary:
	if not is_valid_world_id(world_id):
		push_error("Identifiant de monde invalide.")
		return {}

	var save_path: String = get_save_path(world_id)
	var data: Dictionary = read_save_file(save_path, world_id)

	if not data.is_empty():
		return data

	var backup_path: String = save_path + ".bak"

	if FileAccess.file_exists(backup_path):
		push_warning("Tentative de récupération de la sauvegarde précédente.")
		return read_save_file(backup_path, world_id)

	return {}

func create_world(world_name: String, seed: int) -> Error:
	var clean_name: String = world_name.strip_edges()

	if clean_name.is_empty():
		return ERR_INVALID_PARAMETER

	var world_id: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var data: Dictionary = WorldSaveData.create_new(world_id, clean_name, seed)

	var error: Error = save_world(data)

	if error == OK:
		current_world = data

	return error


func select_world(world_id: String) -> Error:
	var data: Dictionary = load_world(world_id)

	if data.is_empty():
		return ERR_INVALID_DATA

	current_world = data
	return OK


func save_current_world(player: Player) -> Error:
	if current_world.is_empty():
		return ERR_UNCONFIGURED

	return save_game(current_world, player)


func clear_current_world() -> void:
	current_world = {}

func save_game(data: Dictionary, player: Player) -> Error:
	if not is_instance_valid(player) or not player.is_node_ready():
		return ERR_INVALID_PARAMETER

	var world_data: Dictionary = Generator.get_world_save_data()
	var player_data: Dictionary = player.get_save_data()
	var quest_data: Dictionary = Quests.get_save_data()

	if world_data.is_empty() or player_data.is_empty() or quest_data.is_empty():
		return ERR_INVALID_DATA

	var snapshot: Dictionary = data.duplicate(true)
	snapshot["terrain"] = world_data["terrain"]
	snapshot["player"] = player_data
	snapshot["quests"] = quest_data

	var error: Error = save_world(snapshot)

	if error != OK:
		return error

	data["terrain"] = snapshot["terrain"]
	data["player"] = snapshot["player"]
	data["quests"] = snapshot["quests"]
	data["world"]["updated_at"] = snapshot["world"]["updated_at"]

	return OK

func delete_world(world_id: String) -> Error:
	if not is_valid_world_id(world_id):
		return ERR_INVALID_PARAMETER

	var save_path: String = get_save_path(world_id)

	var paths: Array[String] = [
		save_path + ".tmp",
		save_path + ".bak",
		save_path
	]

	for path in paths:
		if not FileAccess.file_exists(path):
			continue

		var error: Error = DirAccess.remove_absolute(path)

		if error != OK:
			push_error("Impossible de supprimer : " + path)
			return error

	if current_world.get("world", {}).get("id", "") == world_id:
		clear_current_world()

	return OK

func read_save_file(path: String, expected_id: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_warning("Impossible de lire : " + path)
		return {}

	var content: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var error: Error = json.parse(content)

	if error != OK:
		push_warning("JSON invalide dans %s, ligne %d : %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}

	if not json.data is Dictionary:
		push_warning("La sauvegarde doit contenir un dictionnaire.")
		return {}

	var data: Dictionary = json.data

	if data.get("format_version") != WorldSaveData.FORMAT_VERSION:
		push_warning("Version de sauvegarde incompatible : " + path)
		return {}

	for section in ["world", "generation", "terrain", "player", "quests"]:
		if not data.get(section) is Dictionary:
			push_warning("Section manquante ou invalide : " + section)
			return {}

	if data["world"].get("id") != expected_id:
		push_warning("L'identifiant du monde ne correspond pas au fichier.")
		return {}

	return data
