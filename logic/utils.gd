# Port of packages/game-logic/src/utils.ts
# Pure helpers shared by the engine, characters and bot logic.
class_name Utils


# Fisher-Yates shuffle (in-place, returns same array)
static func shuffle_array(array: Array) -> Array:
	for i in range(array.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp
	return array


static func generate_id() -> String:
	const CHARS := "abcdefghijklmnopqrstuvwxyz0123456789"
	var out := ""
	for i in range(8):
		out += CHARS[randi() % CHARS.length()]
	return out


# Deep clone — equivalent of JSON.parse(JSON.stringify(obj)) but type-preserving.
static func clone_state(obj):
	if obj is Dictionary or obj is Array:
		return obj.duplicate(true)
	return obj


static func add_log(state: Dictionary, message: String) -> void:
	state["log"].push_back({"message": message, "timestamp": int(Time.get_unix_time_from_system() * 1000.0)})
	if state["log"].size() > 200:
		state["log"].pop_front()


# JS Array.prototype.findIndex equivalent
static func find_index(arr: Array, cb: Callable) -> int:
	for i in range(arr.size()):
		if cb.call(arr[i]):
			return i
	return -1


# JS Array.prototype.find equivalent (returns null when not found)
static func find_item(arr: Array, cb: Callable):
	for item in arr:
		if cb.call(item):
			return item
	return null


# Error helpers — GDScript has no exceptions, so handlers return either a
# state Dictionary or an error wrapper produced by err().
static func err(msg: String) -> Dictionary:
	return {"__error": msg}


static func is_err(value) -> bool:
	return value is Dictionary and value.has("__error")
