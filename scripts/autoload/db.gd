extends Node

# Loads and validates all game data from res://data/. Everything gameplay-
# related (cards, recipes, packs) is data-driven so new content is a JSON edit.

var cards := {}         # id -> card def
var card_order := []    # ids in file order
var recipes := []       # recipe defs in file order
var recipe_index := {}  # signature -> recipe def
var packs := {}         # id -> pack def

const VALID_TYPES := ["unit", "nature", "resource", "food", "building", "special"]


func _ready() -> void:
	var errs := load_all()
	for e in errs:
		push_error("[Db] %s" % e)


func card(id: String) -> Dictionary:
	return cards.get(id, {})


func has_card(id: String) -> bool:
	return cards.has(id)


func pack(id: String) -> Dictionary:
	return packs.get(id, {})


# Returns an array of human-readable data errors; empty means valid.
# Safe to call on a bare instance (used by the CI smoke test).
func load_all() -> Array:
	var errs := []
	cards = {}
	card_order = []
	recipes = []
	recipe_index = {}
	packs = {}

	var cards_doc = _load_json("res://data/cards.json", errs)
	var recipes_doc = _load_json("res://data/recipes.json", errs)
	var packs_doc = _load_json("res://data/packs.json", errs)
	if not errs.is_empty():
		return errs

	for c in cards_doc.get("cards", []):
		var id := String(c.get("id", ""))
		if id == "":
			errs.append("Card with missing id")
			continue
		if cards.has(id):
			errs.append("Duplicate card id '%s'" % id)
			continue
		if not String(c.get("type", "")) in VALID_TYPES:
			errs.append("Card '%s' has invalid type '%s'" % [id, c.get("type")])
		cards[id] = c
		card_order.append(id)

	recipes = recipes_doc.get("recipes", [])
	for r in recipes:
		var rid := String(r.get("id", "?"))
		for req in ["inputs", "outputs", "time"]:
			if not r.has(req):
				errs.append("Recipe '%s' missing '%s'" % [rid, req])
		for input_id in r.get("inputs", {}):
			if not cards.has(input_id):
				errs.append("Recipe '%s' input '%s' is not a card" % [rid, input_id])
			if int(r["inputs"][input_id]) <= 0:
				errs.append("Recipe '%s' input '%s' count must be positive" % [rid, input_id])
		for out_id in r.get("outputs", {}):
			if not cards.has(out_id):
				errs.append("Recipe '%s' output '%s' is not a card" % [rid, out_id])
		for k in r.get("keep", []):
			if not r.get("inputs", {}).has(k):
				errs.append("Recipe '%s' keeps '%s' which is not an input" % [rid, k])
		for d in r.get("decrement", []):
			if not r.get("inputs", {}).has(d):
				errs.append("Recipe '%s' decrements '%s' which is not an input" % [rid, d])
			elif cards.has(d) and int(cards[d].get("charges", 0)) <= 0:
				errs.append("Recipe '%s' decrements '%s' which has no charges" % [rid, d])

	recipe_index = RecipeEngine.build_index(recipes, errs)

	for p in packs_doc.get("packs", []):
		var pid := String(p.get("id", ""))
		if pid == "":
			errs.append("Pack with missing id")
			continue
		packs[pid] = p
		for w_id in p.get("weights", {}):
			if not cards.has(w_id):
				errs.append("Pack '%s' weight '%s' is not a card" % [pid, w_id])
			if float(p["weights"][w_id]) <= 0.0:
				errs.append("Pack '%s' weight '%s' must be positive" % [pid, w_id])
		if int(p.get("cost", 0)) <= 0 or int(p.get("count", 0)) <= 0:
			errs.append("Pack '%s' needs positive cost and count" % pid)

	if cards.is_empty():
		errs.append("No cards loaded")
	if recipes.is_empty():
		errs.append("No recipes loaded")

	return errs


static func _load_json(path: String, errs: Array) -> Dictionary:
	if not FileAccess.file_exists(path):
		errs.append("Missing data file %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		errs.append("Failed to parse %s" % path)
		return {}
	return parsed
