extends Node
## Autoload "Save" — saari persistent state ek jagah.
## user://dbw_save.cfg me ConfigFile ke zariye save hota hai.

const SAVE_PATH := "user://dbw_save.cfg"

var data: Dictionary = {}
# Session-only state (persist nahi hota): Number Slide ke free hints.
var slide_hints_left: int = 3

func _ready() -> void:
	load_data()

func _defaults() -> Dictionary:
	return {
		"pb": {},
		"workout": {"date": "", "day": -1, "order": [], "results": {}, "counted": false},
		"streak": {"count": 0, "last_day": -1, "total": 0, "history": []},
	}

func load_data() -> void:
	data = _defaults()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var stored = cfg.get_value("dbw", "data", null)
		if stored is Dictionary:
			for k in stored.keys():
				data[k] = stored[k]
	_normalize()

func _normalize() -> void:
	var w: Dictionary = data.get("workout", {})
	for k in ["date", "day", "order", "results", "counted"]:
		if not w.has(k):
			w[k] = _defaults()["workout"][k]
	data["workout"] = w
	var st: Dictionary = data.get("streak", {})
	for k in ["count", "last_day", "total", "history"]:
		if not st.has(k):
			st[k] = _defaults()["streak"][k]
	data["streak"] = st
	if not (data.get("pb") is Dictionary):
		data["pb"] = {}

func persist() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("dbw", "data", data)
	cfg.save(SAVE_PATH)

# --- Personal bests ---

func get_pb(game_id: String) -> int:
	return int(data["pb"].get(game_id, 0))

func submit_pb(game_id: String, score: int) -> bool:
	if score > get_pb(game_id):
		data["pb"][game_id] = score
		persist()
		return true
	return false

# --- Dates ---

func today_str() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]

func day_number() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

# --- Today's Workout ---

func ensure_today_workout() -> Dictionary:
	var w: Dictionary = data["workout"]
	if str(w.get("date", "")) != today_str():
		var order: Array = ["sequence_memory", "number_slide", "color_word_clash", "odd_one_out", "path_memory"]
		if day_number() % 2 == 1:
			order.reverse()
		w = {"date": today_str(), "day": day_number(), "order": order, "results": {}, "counted": false}
		data["workout"] = w
		persist()
	return w

func workout_done_count() -> int:
	var w := ensure_today_workout()
	return (w["results"] as Dictionary).size()

func workout_total() -> int:
	var w := ensure_today_workout()
	return (w["order"] as Array).size()
