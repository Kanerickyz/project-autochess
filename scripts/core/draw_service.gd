class_name DrawService
extends RefCounted
## Draws a per-wave hand subset from the constructed deck (without replacement).


static func draw_wave_hand(
	deck: DeckState,
	draw_count: int,
	rng: RandomNumberGenerator = null,
) -> Array[DeckEntry]:
	var result: Array[DeckEntry] = []
	if deck == null or draw_count <= 0:
		return result

	var pool: Array[DeckEntry] = deck.get_entries()
	if pool.is_empty():
		return result

	var take := mini(draw_count, pool.size())
	var local_rng := rng
	if local_rng == null:
		local_rng = RandomNumberGenerator.new()
		local_rng.randomize()

	# Partial Fisher–Yates: shuffle only the prefix we keep.
	for i in take:
		var j := local_rng.randi_range(i, pool.size() - 1)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
		result.append(pool[i])
	return result
