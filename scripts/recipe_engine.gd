class_name RecipeEngine
extends RefCounted

# Exact multiset matching: a stack's contents (card ids, order ignored) must
# equal a recipe's inputs exactly for work to begin. Signatures are canonical
# strings like "tree:1|villager:1" so lookup is a single dictionary hit.


static func signature_of_counts(counts: Dictionary) -> String:
	var keys := counts.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k in keys:
		parts.append("%s:%d" % [k, int(counts[k])])
	return "|".join(parts)


static func signature_of_ids(ids: Array) -> String:
	var counts := {}
	for id in ids:
		counts[id] = int(counts.get(id, 0)) + 1
	return signature_of_counts(counts)


# Returns { signature: recipe_def }. Duplicate signatures are reported through
# the errors array so data problems fail loudly in tests instead of silently
# shadowing a recipe.
static func build_index(recipes: Array, errors: Array) -> Dictionary:
	var index := {}
	for r in recipes:
		var sig := signature_of_counts(r["inputs"])
		if index.has(sig):
			errors.append("Duplicate recipe signature '%s' (%s vs %s)" % [sig, index[sig]["id"], r["id"]])
			continue
		index[sig] = r
	return index
