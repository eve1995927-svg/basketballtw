extends RefCounted
## Both sides use the same possession model. Ratings are game values, not real forecasts.

static func attack(team: Dictionary, rival: Dictionary, possessions: int, rng: RandomNumberGenerator) -> Dictionary:
	var edge := float(team.get("rating", 75)) - float(rival.get("rating", 75))
	var accuracy := edge * 0.004 + (float(team.get("offense", 0)) - float(rival.get("defense", 0))) * 0.018
	var turnovers := clampf(0.13 + (float(rival.get("defense", 0)) - float(team.get("offense", 0))) * 0.012, 0.06, 0.22)
	var threes := 0
	var points := 0
	for _p in possessions:
		if rng.randf() < turnovers:
			continue
		if rng.randf() < 0.12:
			for _ft in 2:
				points += int(rng.randf() < 0.76)
			continue
		var three := rng.randf() < float(team.get("three_rate", 0.36))
		# Every possession gets a small quality swing so repeated matchups do not
		# collapse into the same scoreline while team strength still matters.
		var shot_quality := rng.randf_range(-0.075, 0.075)
		var made := rng.randf() < clampf((0.35 if three else 0.54) + accuracy + shot_quality, 0.16, 0.80)
		if made:
			points += 3 if three else 2
			threes += int(three)
		elif rng.randf() < 0.24 and rng.randf() < clampf(0.53 + accuracy, 0.2, 0.8):
			points += 2
	return {"points": points, "threes": threes}

static func period(a: Dictionary, b: Dictionary, rng: RandomNumberGenerator, overtime := false) -> Dictionary:
	var pace := (float(a.get("pace", 23)) + float(b.get("pace", 23))) * 0.5
	# Pace and game flow vary every period; avoid the old near-identical scorelines.
	var possessions := maxi(5, int(round((pace + rng.randf_range(-4.5, 4.5)) * (0.5 if overtime else 1.0))))
	var left := attack(a, b, possessions, rng)
	var right := attack(b, a, possessions, rng)
	return {"a": left.points, "b": right.points, "threes_a": left.threes, "threes_b": right.threes}

static func game(a: Dictionary, b: Dictionary, rng: RandomNumberGenerator) -> Array[int]:
	var score: Array[int] = [0, 0]
	for q in 4:
		var result := period(a, b, rng)
		score[0] += int(result.a)
		score[1] += int(result.b)
	var overtime_count := 0
	while score[0] == score[1] and overtime_count < 3:
		var result := period(a, b, rng, true)
		score[0] += int(result.a)
		score[1] += int(result.b)
		overtime_count += 1
	if score[0] == score[1]:
		# Safety fallback prevents a pathological endless tie without changing normal games.
		score[0] += 1
	return score
