extends "res://tests/mobile_regression.gd"
## Extended offline audit. Never connects to the player's account or store.

const MatchSimulator = preload("res://scripts/match_simulator.gd")

func fresh_game() -> void:
	if is_instance_valid(game):
		game.match_play_id += 1
		game.queue_free()
		await process_frame
	game = TestGame.new()
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame

func run() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("TB-Mobile-Test-"):
		quit(2)
		return
	await fresh_game()
	await test_no_headline_selection()
	await test_catalog()
	await test_veteran_and_training_rules()
	await test_duplicate_release_and_sort()
	await test_scout_distribution()
	await test_free_agent_signing()
	await test_economy_update()
	await test_economy()
	await test_store_cosmetics()
	await test_draft_and_acquisition()
	await test_slot_isolation()
	test_purchase_validation()
	await test_extra_records()
	await test_season_simulation()
	await test_series_and_balance()
	if OS.get_environment("TB_TEST_VISUAL") == "1" or OS.get_environment("TB_TEST_LAYOUT") == "1":
		await extended_visual_tour()
	game.match_play_id += 1
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) == 0, "full audit leaves no orphan nodes")
	print("TEST_USER_DIR=" + OS.get_user_data_dir())
	print("FULL_TEST_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func test_no_headline_selection() -> void:
	# Simulate a player leaving the initial selection page without tapping a card.
	game.reset_club_state()
	game.show_dashboard()
	await process_frame
	check(game.team_players.size() >= 7, "new club gets a playable roster when no headline player is selected")
	check(not str(game.selected_live_player).is_empty(), "automatic starter recommendation is recorded")
	check(game.team_players.any(func(p): return str(p.get("name", "")) == game.selected_live_player), "recommended headline player is in the starting roster")
	var rng := RandomNumberGenerator.new()
	rng.seed = 111
	var scores := {}
	for i in 12:
		var score: Array[int] = MatchSimulator.game({"rating": 76, "offense": 0.2, "defense": 0.2, "pace": 24, "three_rate": 0.38}, {"rating": 75, "offense": 0.2, "defense": 0.2, "pace": 24, "three_rate": 0.36}, rng)
		scores["%d-%d" % [score[0], score[1]]] = true
	check(scores.size() >= 4, "repeated matches produce varied scores instead of a fixed result")

func test_store_cosmetics() -> void:
	await fresh_game()
	check(game.home_resource_number(39392857) == "39,392,857", "home HUD keeps eight-digit balances exact")
	check(game.home_resource_number(123456789) == "123,456,789", "home HUD keeps hundred-million balances exact")
	check(game.home_resource_number(1280) == "1,280", "home HUD groups short balances without rounding")
	var product_ids: Array = game.store_products().map(func(product: Dictionary): return str(product.id))
	check(not product_ids.has("pack_rookie") and not product_ids.has("training_glow"), "store does not sell card packs, training glow, or reveal animation")
	for city_id in ["arena_taipei", "arena_new_taipei", "arena_taichung", "arena_tainan", "arena_kaohsiung", "arena_hualien"]:
		check(int(game.store_product_by_id(city_id).gold) == 300, "Taiwan city arena costs 300 gold: " + city_id)
	for virtual_id in ["arena_champion", "arena_neon", "arena_night"]:
		check(int(game.store_product_by_id(virtual_id).gold) == 500, "virtual arena costs 500 gold: " + virtual_id)
	game.gold = 1000
	var champion: Dictionary = game.store_product_by_id("arena_champion")
	game.activate_store_product(champion)
	await process_frame
	check(game.gold == 500, "arena cosmetic deducts its gold price once")
	check(game.store_cosmetics_owned.has("arena_champion"), "arena cosmetic is permanently recorded as owned")
	check(game.supporter_theme == "冠軍金色主場", "purchased arena cosmetic is applied immediately")
	game.activate_store_product(champion)
	await process_frame
	check(game.gold == 500, "owned arena cosmetic can be reapplied without another charge")
	game.set_supporter_theme("賽博龐克主場")
	await process_frame
	check(game.supporter_theme == "冠軍金色主場", "locked arena cannot be applied from the showcase shortcut")
	check(game.active_menu == "store" and game.store_selected_product == "arena_neon", "locked arena shortcut opens the matching store item")
	game.gold = 5000
	game.activate_store_product(game.store_product_by_id("vault_plus_10"))
	await process_frame
	check(game.vault_capacity() == 30 and game.gold == 4700, "vault upgrade adds 10 slots for 300 gold")
	game.activate_store_product(game.store_product_by_id("second_team"))
	await process_frame
	check(game.second_team_unlocked and game.gold == 4400, "second team unlock costs 300 gold")
	game.activate_store_product(game.store_product_by_id("event_jones"))
	await process_frame
	check(game.jones_pass and game.gold == 3800, "Jones Cup unlock costs 600 gold")
	var before_monthly: int = game.gold
	game.complete_purchase("monthly_pass")
	await process_frame
	check(game.gold == before_monthly + 400 and game.store_cosmetics_owned.has("arena_monthly"), "monthly pass grants 400 immediate gold and the limited arena")
	var before_bundle: int = game.gold
	game.complete_purchase("gold_300")
	await process_frame
	check(game.gold == before_bundle + 300, "NT$30 gold bundle grants 300 gold at 1:10")

func test_veteran_and_training_rules() -> void:
	await fresh_game()
	var veteran: Dictionary = game.to_game_player({"name":"田壘", "ovr":81, "origin_team_id":"sbl_yulon"})
	check(veteran.get("pos", "") == "PF", "田壘 uses curated PF position")
	var guard: Dictionary = game.to_game_player({"name":"李學林", "ovr":75, "origin_team_id":"sbl_yulon"})
	check(guard.get("pos", "") == "PG", "李學林 uses curated PG position")
	var retired: Dictionary = game.to_game_player({"name":"呂政儒", "ovr":74, "origin_team_id":"sbl_yulon"})
	check(retired.get("pos", "") == "SF" and retired.get("golden_generation", false), "呂政儒 is a retired SF golden veteran")
	var imported_retired: Dictionary = game.to_game_player({"name":"呂政儒", "position":"SG/SF", "ovr":74, "origin_team_id":"kings"})
	check(imported_retired.get("pos", "") == "SF", "curated veteran position overrides stale public roster position")
	for profile in game.career_rules.get("golden_generation", []):
		if not (profile is Dictionary):
			continue
		var curated_name := str(profile.get("name", ""))
		var curated_card: Dictionary = game.to_game_player({"name": curated_name, "position": "SG", "ovr": int(profile.get("ovr", 70))})
		check(curated_card.get("pos", "") == str(profile.get("position", "")), "every golden-generation card keeps curated position: " + curated_name)
	var p: Dictionary = game.team_players[0]
	p["match_appearances"] = 2
	game.team_players[0] = p
	game.training_points = 1
	game.budget_million = 1000
	var before: int = int(p.get("training_sessions", 0))
	game.apply_player_training(0, false)
	check(int(game.team_players[0].get("training_sessions", 0)) == int(before) and game.training_points == 1, "training is gated until three appearances")
	p = game.team_players[0]
	p["match_appearances"] = 3
	game.team_players[0] = p
	game.apply_player_training(0, false)
	check(int(game.team_players[0].get("training_sessions", 0)) == int(before) + 1 and game.training_points == 0, "first training succeeds at 100 percent")
	p = game.team_players[0]
	p["training_sessions"] = 5
	game.team_players[0] = p
	game.training_points = 1
	game.apply_player_training(0, false)
	check(game.training_points == 1 and int(game.team_players[0].get("training_sessions", 0)) == 5, "fifth completed training blocks further attempts")
	var card: Control = game.lobby_player_card(game.team_players[0], false, 0, false, 96)
	check(card.find_child("TrainingBadge", true, false) != null and card.find_child("TrainingGlow", true, false) != null, "trained card shows bonus and glow")
	check(card.find_child("CourtBackground", true, false) != null, "player card places a court behind its cutout portrait")
	card.free()
	var gold_card: Control = game.lobby_player_card(veteran, false, -1, false, 96)
	check(gold_card.find_child("CourtBackground", true, false) != null and gold_card.find_child("PremiumCourtSparkles", true, false) != null, "gold card has a court and subtle premium sparkles")
	gold_card.free()
	var diamond_player: Dictionary = game.to_game_player({"name":"鑽石背景測試", "position":"PG", "ovr":90, "locked_prize":true, "tier":"DIAMOND"})
	var diamond_visual: Control = game.lobby_player_card(diamond_player, false, -1, false, 96)
	check(diamond_visual.find_child("CourtBackground", true, false) != null and diamond_visual.find_child("PremiumCourtSparkles", true, false) != null, "diamond card has a court and subtle premium sparkles")
	diamond_visual.free()
	var promotion_player: Dictionary = game.to_game_player({"name":"升框測試球員", "position":"SG", "ovr":70, "origin_team_id":"sbl_yulon"})
	promotion_player["match_appearances"] = 3
	promotion_player["training_sessions"] = 0
	promotion_player["salary_million"] = game.published_salary(promotion_player)
	game.team_players[0] = promotion_player
	game.training_points = 1
	game.budget_million = 1000
	game.apply_player_training(0, true)
	await process_frame
	check(game.team_players[0].ovr == 71 and game.player_tier_key(game.team_players[0]) == "green", "training threshold promotes gray card to green")
	check(is_instance_valid(game.card_reveal_modal) and game.card_reveal_modal.name == "TierUpReveal", "card-tier promotion opens its reveal")
	if is_instance_valid(game.card_reveal_modal):
		check(game.card_reveal_modal.find_child("OldTierCard", true, false) != null, "tier reveal keeps the old card for the crack transition")
		check(game.card_reveal_modal.find_child("NewTierCard", true, false) != null, "tier reveal prepares the promoted card")
		check(game.card_reveal_modal.find_child("TierUpCracks", true, false) != null, "tier reveal includes the light-crack layer")
		game.close_card_reveal()
		await process_frame

func test_duplicate_release_and_sort() -> void:
	await fresh_game()
	var base: Dictionary = game.to_game_player({"name":"測試球員", "position":"SG", "ovr":76, "origin_team_id":"sbl_yulon"})
	game.card_inventory = [base.duplicate(true), base.duplicate(true)]
	game.gold = 100
	check(game.can_release_duplicate(game.card_inventory[0]), "duplicate vault card can be released")
	var reward: int = game.duplicate_gold_for(base)
	game.release_vault_player(0, true)
	check(game.card_inventory.size() == 1 and game.gold == 100 + reward, "releasing duplicate card grants rarity gold and keeps the other copy")
	game.card_inventory.append(base.duplicate(true))
	game.card_inventory[0]["ovr"] = 90
	game.card_inventory[1]["ovr"] = 70
	var sorted: Array[int] = game.sorted_vault_indices()
	check(sorted.size() == 2 and sorted[0] == 0, "vault default sorting orders OVR high to low")
	game.vault_sort_mode = "ovr_asc"
	sorted = game.sorted_vault_indices()
	check(sorted.size() == 2 and sorted[0] == 1, "vault sorting can switch to OVR low to high")

func settle_extra_fixture(won: bool) -> void:
	game.start_extra_match()
	game.match_play_id += 1
	game.quarter_scores = [[25, 25, 25, 25], [20, 20, 20, 20]] if won else [[20, 20, 20, 20], [25, 25, 25, 25]]
	game.last_score.assign([100, 80] if won else [80, 100])
	game.reveal_quarter = 4
	game.show_post_match()
	await process_frame

func test_extra_records() -> void:
	await fresh_game()
	game.pro_top2 = true
	game.easl_pass = true
	game.jones_pass = true
	game.national_unlocked = true
	game.salary_cap = 100000
	game.reset_league_table()
	var league_before: Dictionary = game.league_table.duplicate(true)
	var season_before := [game.season_games, game.season_wins, game.season_losses]
	game.training_points = 0
	for eid in ["easl", "bcl", "jones", "wcq"]:
		game.pick_extra_entry(eid, {})
		var opponent_id: String = game.extra_queue[0].id
		var training_before: int = game.training_points
		await settle_extra_fixture(true)
		check(game.training_points == training_before + 1, "extra-match win awards exactly one training point: " + eid)
		var records: Dictionary = game.extra_run(eid).records
		check(records.club.w == 1 and records.club.l == 0, eid + " records user win")
		check(records[opponent_id].l == 1, eid + " records opponent loss")
		game.show_post_match()
		check(records.club.w == 1, eid + " opening result twice does not count again")
		game.save_game()
		game.load_game(false)
		check(game.extra_run(eid).records.club.w == 1, eid + " win survives reload")
		game.salary_cap = 100000
		await settle_extra_fixture(false)
		check(game.extra_run(eid).records.club.w == 1 and game.extra_run(eid).records.club.l == 1, eid + " loss preserves cumulative win")
		check(game.extra_wins == 0 and game.extra_queue.is_empty(), eid + " loss resets only championship progress")
		game.pick_extra_entry(eid, {})
		check(game.extra_run(eid).records.club.l == 1, eid + " retry retains records")
		var user_rows: Array = game.extra_preview_standings(eid).filter(func(row): return row.get("id") == "club")
		check(user_rows[0].w == 1 and user_rows[0].l == 1 and user_rows[0].last5 == "勝 敗", eid + " table uses actual record and recent form")
		check(user_rows[0].next == game.extra_queue[0].name, eid + " table uses actual scheduled opponent")
	for tid in league_before:
		for key in ["w", "l", "pf", "pa", "last5"]:
			check(game.league_table.get(tid, {}).get(key) == league_before[tid][key], "extra matches preserve league record: " + str(tid) + "/" + key)
	check([game.season_games, game.season_wins, game.season_losses] == season_before, "extra matches never alter season wins/games/losses")
	game.load_extra_run("jones")
	for i in 3:
		await settle_extra_fixture(true)
	check(game.extra_champions.get("jones", false), "three wins still complete event")
	check(game.extra_run("jones").records.club.w == 4, "championship includes all wins")
	game.show_extra_event("easl")
	game.show_result_hub()
	check(game.last_match_gain.event_id == "jones", "last result keeps its own event when browsing another event")
	check(game.find_child("ResultDetails", true, false) != null, "extra match appears in result hub")
	game.pick_extra_entry("jones", {})
	check(game.extra_run("jones").records.club.w == 4, "championship replay retains history")
	game.save_game()
	game.load_game(false)
	check(game.extra_run("jones").records.club.w == 4 and game.extra_run("easl").records.club.w == 1, "event records remain isolated after reload")
	game.extra_runs = {"bcl": {"entry": "club", "wins": 2, "queue": []}}
	game.load_extra_run("bcl")
	check(game.extra_run("bcl").records.club.w == 2 and game.extra_run("bcl").legacy_record, "legacy run restores only known wins with disclosure")
	game.extra_wins = 0
	game.save_extra_run()
	check(game.extra_run("bcl").records.club.w == 2, "resetting migrated streak never erases historical wins")
	await fresh_game()
	var body: Label = game.label("內文", 12)
	check(body.get_theme_font("font") == game.FONT_REGULAR, "body copy respects regular font weight")
	if game.is_handheld():
		check(body.get_theme_font_size("font_size") == 16 and body.get_theme_constant("outline_size") == 1, "mobile copy has smaller readable type without heavy outlines")
	body.free()

func test_catalog() -> void:
	var ids := {}
	var count := 0
	for team in game.league_teams:
		var purple_count := 0
		check(game.team_logo_tex(str(team.id)) != null, "team logo exists: " + str(team.id))
		for raw in team.players:
			check(not ids.has(str(raw.id)), "unique player id " + str(raw.id))
			ids[str(raw.id)] = true
			check(str(raw.get("origin_team_id", "")) == str(team.id), "player origin matches catalog team")
			var p: Dictionary = game.to_game_player(raw)
			if game.player_tier_key(p) == "purple":
				purple_count += 1
			check(not game.player_pos_list(p).is_empty(), "listed player has game position")
			check(p.ovr >= 60 and p.ovr <= 90 and p.salary_million > 0, "valid game values")
			check(ResourceLoader.exists(game.unique_portrait_path(p)), "assigned illustration exists")
			check(game.card_frame_for(game.player_tier_key(p)) != null, "card tier has frame")
			count += 1
		check(purple_count <= 5, "at most five base purple cards per team: " + str(team.id))
	var fixture := {"id": "kings", "players": []}
	for i in range(8):
		fixture.players.append({"id": "cap_fixture_%d" % i, "name": "測試球員%d" % i, "ovr": 90 - i % 5})
	var normalized: Dictionary = game.normalized_catalog_team(fixture)
	check(normalized.players.filter(func(p): return p.ovr >= 86).size() == 5, "future catalog with eight purples is limited to five")
	check(fixture.players.filter(func(p): return p.ovr >= 86).size() == 8, "catalog normalization never mutates its input")
	var trained: Dictionary = game.refresh_stored_player({"id": "kings_9", "name": "林彥廷", "origin_team_id": "kings", "ovr": 90, "training_sessions": 12})
	check(trained.ovr == 90 and trained.training_sessions == 12, "catalog update preserves previously trained purple cards")
	for who in ["熊祥泰", "林彥廷", "喬納森"]:
		var found := 0
		for raw in game.all_league_players():
			if raw.name == who:
				found += 1
				check(raw.origin_team_id == "kings", "requested player belongs to Kings: " + who)
		check(found == 1, "requested player exists exactly once: " + who)
	print("CATALOG_AUDIT teams=%d players=%d" % [game.league_teams.size(), count])
	var catalog_export: Array = []
	for raw in game.all_league_players():
		var card: Dictionary = game.to_game_player(raw)
		catalog_export.append({"id": card.id, "display_name": card.name, "position": card.position, "ovr": card.ovr, "skill_name": card.skill_name})
	var audit_output := OS.get_environment("TB_TEST_OUTPUT")
	if not audit_output.is_empty():
		DirAccess.make_dir_recursive_absolute(audit_output)
		var export_file := FileAccess.open(audit_output.path_join("player_catalog.json"), FileAccess.WRITE)
		check(export_file != null, "converted catalog is exported for release database parity check")
		if export_file != null:
			export_file.store_string(JSON.stringify(catalog_export, "\t"))
			export_file.close()
	var market_pool: Array[Dictionary] = game.market_player_pool()
	var market_expected := 0
	for raw in game.all_league_players():
		var converted: Dictionary = game.to_game_player(raw)
		if game.player_tier_key(converted) not in ["gold", "diamond"] and int(converted.get("ovr", 70)) < 80 and not game.team_has_player(converted):
			market_expected += 1
	check(market_pool.size() == market_expected, "trade and free-agent markets expose non-gold/non-diamond players below OVR 80")
	for card in market_pool:
		check(game.player_tier_key(card) not in ["gold", "diamond"] and int(card.get("ovr", 70)) < 80 and not game.team_has_player(card), "market excludes premium, owned, and OVR 80+ cards")
	for who in ["熊祥泰", "林彥廷", "喬納森"]:
		check(market_pool.any(func(p): return p.name == who), "requested Kings player is obtainable in market: " + who)
	for event_id in ["easl", "bcl", "jones", "wcq"]:
		for team in game.extra_event_teams(event_id):
			if not bool(team.get("is_user", false)):
				check(team.get("players", []).size() >= 5, "extra opponent has a sourced playable roster: %s/%s" % [event_id, team.get("id", "")])
		game.show_extra_event(event_id)
		var opponent_count: int = game.extra_event_teams(event_id).filter(func(team): return not bool(team.get("is_user", false))).size()
		var roster_buttons := game.find_children("ExtraTeam_*", "Button", true, false)
		check(roster_buttons.size() == opponent_count, "every extra-event opponent row opens a roster: " + event_id)
		if not roster_buttons.is_empty():
			roster_buttons[0].pressed.emit()
			await process_frame
			check(game.find_child("GuideModal", true, false) != null, "opponent roster opens from standings row: " + event_id)
			var roster_has_ovr := false
			for roster_label in game.find_child("GuideModal", true, false).find_children("*", "Label", true, false):
				if str(roster_label.text).contains("OVR"):
					roster_has_ovr = true
			check(roster_has_ovr, "opponent roster includes position and OVR details: " + event_id)
			game.close_guide_modal()
	check(game.position_data_missing({"name": "陳信安", "ovr": 80}), "missing veteran source position is explicitly identified")

func unowned_player() -> Dictionary:
	for raw in game.public_players:
		var p: Dictionary = game.to_game_player(raw)
		if not game.team_has_player(p) and not game.is_foreigner(p) and not game.is_foreign_student(p) and not game.is_veteran_player(p):
			return p
	return {}

func test_scout_distribution() -> void:
	var expected := {"gold": 1, "purple": 5, "red": 10, "blue": 20, "green": 30, "cyan": 34}
	var counts := {}
	for roll in range(1, 101):
		var rarity: String = game.scout_rarity_for_roll(roll)
		counts[rarity] = int(counts.get(rarity, 0)) + 1
	check(counts == expected, "all 100 roll values map exactly to 1/5/10/20/30/34")
	var pool: Array[Dictionary] = game.scout_player_pool()
	var buckets: Dictionary = game.scout_rarity_buckets(pool)
	var bucket_sizes := {}
	for key in expected:
		check(not buckets[key].is_empty(), "real scout catalog contains " + key)
		bucket_sizes[key] = buckets[key].size()
	for card in pool:
		check(not game.is_locked_prize(card) and game.player_tier_key(card) != "diamond", "no diamond in scout source")
	print("SCOUT_AUDIT weights=%s pool=%s" % [expected, bucket_sizes])
	game.show_gacha_market()
	var saved_initial: Dictionary = Store.read_save(game.slot_save_path(game.active_save_slot))
	check(saved_initial.get("gacha_candidates", []).size() == 6, "first displayed scout board is saved immediately")
	game.test_scout_rolls.assign(expected.keys())
	check(game.generate_scout_candidates(), "complete catalog produces six offers")
	for i in 6:
		check(game.player_tier_key(game.gacha_candidates[i]) == expected.keys()[i], "offer follows forced rarity, not fallback")
	var offers: Array = game.gacha_candidates.duplicate(true)
	game.save_game()
	game.load_game(false)
	check(game.gacha_candidates.size() == offers.size(), "save/load retains all six offers, including owned cards")
	for i in mini(offers.size(), game.gacha_candidates.size()):
		var restored: Dictionary = game.gacha_candidates[i]
		for key in ["name", "scout_offer_id", "ovr", "salary_million"]:
			check(restored.get(key) == offers[i].get(key), "offer sale terms survive save/load: " + key)
		check(game.player_tier_key(restored) == game.player_tier_key(offers[i]), "offer color survives reload")
		check(game.scout_point_cost(restored) == game.scout_point_cost(offers[i]), "offer scout price survives reload")
	# Repeated offers of one player must still have distinct transaction identities.
	var candidate: Dictionary = {}
	for card in buckets.cyan:
		if not game.team_has_player(card):
			candidate = card
			break
	check(not candidate.is_empty(), "unowned cyan purchase fixture exists")
	buckets.cyan = [candidate]
	game.gacha_candidates.clear()
	game.test_scout_rolls.assign(["cyan", "cyan", "cyan", "cyan", "cyan", "cyan"])
	game.fill_scout_board_from_buckets(buckets)
	var token: String = game.gacha_candidates[0].scout_offer_id
	game.scout_points = 999
	game.salary_cap = 100000
	var cost: int = game.scout_point_cost(candidate)
	var gold_before: int = game.gold
	var cash_before: int = game.budget_million
	game.claim_scout_choice(0, game.player_identity_key(candidate), token)
	check(game.scout_points == 999 - cost and game.gold == gold_before and game.budget_million == cash_before, "buying a new offer spends only scout points")
	check(game.team_has_player(candidate), "purchased card is in roster or vault")
	game.claim_scout_choice(0, game.player_identity_key(candidate), token)
	check(game.scout_points == 999 - cost, "same-player stale offer cannot charge twice")
	var fake_diamond: Dictionary = candidate.duplicate(true)
	fake_diamond.locked_prize = true
	game.gacha_candidates.assign([fake_diamond])
	game.claim_scout_choice(0)
	check(game.scout_points == 999 - cost, "diamond injected through legacy state cannot be purchased")
	# Missing one color must fail atomically, rather than redistribute its probability.
	var old_offers: Array = game.gacha_candidates.duplicate(true)
	var incomplete_pool: Array[Dictionary] = [candidate]
	game.fill_scout_board_from(incomplete_pool)
	check(game.gacha_candidates == old_offers, "incomplete color pool never falls back to another color")
	await fresh_game()

func test_free_agent_signing() -> void:
	await fresh_game()
	# Open the roster as a player would; it refreshes starter/bench card salaries.
	game.show_roster()
	game.budget_million = 0
	game.gold = 0
	game.scout_points = 0
	var incoming: Dictionary = game.cheap_bench_player()
	check(not incoming.is_empty(), "free-agent fixture is available")
	var salary: int = game.published_salary(incoming)
	var payroll: int = game.roster_salary()
	var before: int = game.team_players.size()
	game.salary_cap = payroll + salary - 1
	game.show_player_sheet(incoming, game.show_free_agent_market, func(): game.sign_free_agent(incoming), "確認自由簽約", -1, true)
	var sign_button: Button = game.find_child("FreeAgentSignButton", true, false)
	check(sign_button != null and sign_button.disabled, "over-cap player cannot confirm from the signing sheet")
	var preview: Label = game.find_child("FreeAgentPayrollPreview", true, false)
	check(preview != null and preview.text.contains("$%d → $%d／$%d 萬" % [payroll, payroll + salary, game.salary_cap]), "signing sheet previews the actual before/after payroll and cap")
	game.sign_free_agent(incoming)
	check(game.team_players.size() == before and game.roster_salary() == payroll, "free signing still rejects payroll one above cap without changing roster")
	game.salary_cap = payroll + salary
	var fee: int = game.free_agent_signing_fee(incoming)
	game.budget_million = fee - 1
	game.sign_free_agent(incoming)
	check(game.team_players.size() == before and game.budget_million == fee - 1, "insufficient funds never change the roster or charge money")
	check(game.can_sign_free_agent(incoming).begins_with("資金不足"), "cash shortage is not mislabeled as a salary-cap problem")
	game.budget_million = fee
	game.show_player_sheet(incoming, game.show_free_agent_market, func(): game.sign_free_agent(incoming), "確認自由簽約", -1, true)
	sign_button = game.find_child("FreeAgentSignButton", true, false)
	check(sign_button != null and not sign_button.disabled, "exact funds and salary room enable signing")
	if sign_button != null:
		sign_button.pressed.emit()
	check(game.roster_has_player(incoming) and game.team_players.size() == before + 1, "funded free agent signs at exact salary cap")
	check(game.roster_salary() == payroll + salary, "signing uses the displayed annual salary, not a 1.2x fee")
	check(game.budget_million == 0 and game.gold == 0 and game.scout_points == 0, "signing deducts the displayed cash fee only, never gold or scouting points")
	game.sign_free_agent(incoming)
	check(game.team_players.size() == before + 1, "repeated confirmation cannot sign the same free agent twice")
	var unavailable: Dictionary = game.cheap_bench_player()
	unavailable["locked_prize"] = true
	game.sign_free_agent(unavailable)
	check(not game.roster_has_player(unavailable), "free signing cannot bypass diamond exclusion")
	unavailable = game.to_game_player(game.career_rules.golden_generation[0])
	check(game.can_sign_free_agent(unavailable) == "自由市場不提供黃金卡或鑽石卡", "veteran rejection uses the market rarity rule")
	game.sign_free_agent(unavailable)
	check(not game.roster_has_player(unavailable), "free signing cannot bypass veteran exclusion")
	game.salary_cap = 100000
	game.budget_million = 9999
	for raw in game.market_player_pool():
		if game.is_foreigner(raw) and not game.team_has_player(raw):
			if game.foreigner_count() >= game.foreigner_limit():
				var count_before: int = game.team_players.size()
				game.sign_free_agent(raw)
				check(game.team_players.size() == count_before and not game.roster_has_player(raw), "free signing still respects foreign-player limit")
				break
	while game.team_players.size() < game.roster_limit():
		var next: Dictionary = game.cheap_bench_player()
		var count_before: int = game.team_players.size()
		game.sign_free_agent(next)
		if game.team_players.size() == count_before:
			break
	check(game.team_players.size() == 12, "legal free signings can fill twelve roster slots")
	unavailable = game.cheap_bench_player()
	game.sign_free_agent(unavailable)
	check(game.team_players.size() == 12 and not game.roster_has_player(unavailable), "free signing cannot bypass twelve-player limit")
	await fresh_game()
	# Old clubs keep their balance rather than being reset to the new starter grant.
	game.team_players.resize(3)
	game.budget_million = 730
	game.gold = 0
	game.scout_points = 0
	game.save_game()
	game.load_game(false)
	var original: Array = game.team_players.duplicate(true)
	check(game.team_players.size() == 3 and game.budget_million == 730, "existing three-player club restores its actual funds without resetting")
	for i in range(4):
		var addition: Dictionary = game.cheap_bench_player()
		check(not addition.is_empty() and game.can_sign_player(addition).is_empty(), "stranded club has an eligible affordable player")
		game.sign_free_agent(addition)
	check(game.team_players.size() == 7 and not game.over_salary_cap(), "club can sign from three to seven players with the affordable SBL scale")
	for player in original:
		check(game.roster_has_player(player), "repair preserves original player " + str(player.name))
	game.save_game()
	var remaining_funds: int = game.budget_million
	game.load_game(false)
	check(game.team_players.size() == 7 and game.budget_million == remaining_funds, "roster and spent funds survive save and reload")
	if game.team_players.size() >= 7:
		game.start_match()
		check(game.match_rewards_pending, "repaired club can actually start a match")
		game.match_play_id += 1
	await fresh_game()

func test_economy_update() -> void:
	await fresh_game()
	game.reset_club_state()
	check(game.budget_million == 300 and game.salary_cap == 3000, "new clubs start with 300 cash and an independent 3000 salary cap")
	check(game.gold == 100 and game.scout_points == 20, "new club starts with 100 gold and 20 scout points")
	var sbl_count := 0
	for team in game.league_teams:
		if team.league != "SBL":
			continue
		for raw in team.players:
			var player: Dictionary = game.to_game_player(raw)
			if game.is_veteran_player(player) or game.is_locked_prize(player):
				continue
			sbl_count += 1
			var salary: int = game.published_salary(player)
			check(salary >= 50 and salary <= 300, "SBL salary stays within 50–300: " + str(player.name))
			player.ovr = 65
			check(game.published_salary(player) == 50, "SBL entry-level card costs 50")
			player.ovr = 90
			player.training_sessions = 50
			check(game.published_salary(player) == 300, "training cannot push SBL salary above 300")
	check(sbl_count > 30, "salary audit covers the SBL catalog")
	check(game.published_salary({"name": "阿巴西", "ovr": 88, "origin_team_id": "dea"}) == 2500, "pro-league star contract remains unchanged")
	await fresh_game()
	game.show_roster()
	game.club_name = "保留中的俱樂部"
	game.budget_million = 436
	game.gold = 777
	game.scout_points = 23
	game.training_points = 9
	game.season_games = 3
	game.season_wins = 2
	game.season_losses = 1
	game.card_inventory.append(unowned_player())
	game.tutorial_seen = true
	game.sfx_on = false
	game.bgm_on = false
	game.bgm_volume = 0.17
	game.save_audio_settings()
	var audio_before := FileAccess.get_file_as_string(game.AUDIO_SETTINGS_PATH)
	var legacy: Dictionary = game.collect_save_data().duplicate(true)
	legacy.erase("economy_version")
	legacy.team_players[0].salary_million = 360
	var path: String = game.slot_save_path(0)
	check(Store.write_save(path, legacy) == OK, "legacy update fixture saves")
	game.load_game(false)
	check(game.budget_million == 1436, "old balance is preserved and receives exactly 1000 compensation")
	var current: Dictionary = game.collect_save_data()
	for key in ["club_name", "club_logo_id", "gold", "scout_points", "training_points", "season_games", "season_wins", "season_losses", "selected_tactic", "selected_defense", "tutorial_seen", "current_league", "championships", "draft_state"]:
		check(current[key] == legacy[key], "update preserves existing save field: " + key)
	for field in ["team_players", "card_inventory"]:
		check(current[field].size() == legacy[field].size(), "update preserves card count: " + field)
		for i in legacy[field].size():
			check(game.player_identity_key(current[field][i]) == game.player_identity_key(legacy[field][i]), "update preserves card identity and order")
	check(game.team_players[0].salary_million <= 300, "existing SBL card salary migrates down")
	check(FileAccess.get_file_as_string(game.AUDIO_SETTINGS_PATH) == audio_before, "update does not rewrite sound settings")
	var backup: Dictionary = Store.read_save(path + ".before_economy_v1")
	check(not backup.is_empty(), "original legacy save has a permanent pre-update backup")
	var after: Dictionary = Store.read_save(path)
	check(after.economy_version == game.ECONOMY_VERSION and after.budget_million == 1436, "migration and compensation are committed together")
	game.load_game(false)
	game.load_game(false)
	check(game.budget_million == 1436, "repeated reloads never repeat the compensation")
	# A second, stranded old slot must migrate independently without touching slot zero.
	legacy.team_players.resize(3)
	legacy.budget_million = 0
	game.active_save_slot = 1
	Store.write_save(game.slot_save_path(1), legacy)
	game.load_game(false)
	check(game.team_players.size() == 3 and game.budget_million == 1000, "stranded old club gets cash without losing its original three players")
	for i in 4:
		game.sign_free_agent(game.cheap_bench_player())
	check(game.team_players.size() == 7 and game.budget_million >= 0 and not game.over_salary_cap(), "compensation and lower SBL salaries let the stranded club rebuild")
	game.start_match()
	check(game.match_rewards_pending, "migrated three-player club can resume playing")
	game.match_play_id += 1
	check(Store.read_save(path).budget_million == 1436, "second-slot recovery never changes the first slot")
	await fresh_game()
	game.show_roster()
	for won in [true, false]:
		game.start_match()
		game.match_play_id += 1
		var balance: int = game.budget_million
		var gold_before: int = game.gold
		var scout_before: int = game.scout_points
		game.quarter_scores = [[25, 25, 25, 25], [20, 20, 20, 20]] if won else [[20, 20, 20, 20], [25, 25, 25, 25]]
		game.last_score.assign([100, 80] if won else [80, 100])
		game.reveal_quarter = 4
		game.show_post_match()
		var reward: int = 20 if won else 10
		check(game.budget_million == balance + reward, "regular match pays the configured win/loss cash")
		check(game.last_match_gain.budget == reward and game.last_gain_body().contains("資金"), "result reports the cash actually awarded")
		if won:
			check(game.gold - gold_before >= 5 and game.gold - gold_before <= 10 and game.scout_points - scout_before >= 1 and game.scout_points - scout_before <= 3, "win gold and scouting rewards follow the current reward table")
		else:
			check(game.gold == gold_before and game.scout_points == scout_before, "loss still gives no gold or scouting points")
		game.show_post_match()
		game.load_game(false)
		game.show_post_match()
		check(game.budget_million == balance + reward, "reopened and reloaded result never pays cash twice")
	await fresh_game()
	game.pro_top2 = true
	game.jones_pass = true
	for won in [true, false]:
		game.pick_extra_entry("jones", {})
		var balance: int = game.budget_million
		var gold_before: int = game.gold
		var scout_before: int = game.scout_points
		await settle_extra_fixture(won)
		var reward: int = 20 if won else 10
		check(game.budget_million == balance + reward, "extra match pays win/loss cash")
		check(game.gold == gold_before and game.scout_points == scout_before, "extra-match gold/scout rules remain unchanged")
		game.load_game(false)
		game.show_post_match()
		check(game.budget_million == balance + reward, "extra cash reward cannot duplicate after reload")
	await fresh_game()

func test_economy() -> void:
	game.salary_cap = 100000
	var incoming := unowned_player()
	check(not incoming.is_empty(), "unowned test player found")
	game.card_inventory.append(incoming)
	var before: int = game.team_players.size()
	game.place_inventory_card(0)
	check(game.team_players.size() == before + 1 and game.card_inventory.is_empty(), "vault card can register when there is room")
	await process_frame
	await fresh_game()
	game.coaches_owned.append("sbl_press")
	game.salary_cap = game.roster_salary()
	var old_coach: String = game.coach_id
	var old_gold: int = game.gold
	game.hire_coach("sbl_press")
	check(game.coach_id == old_coach and game.gold == old_gold, "owned coach cannot silently exceed salary cap")
	await fresh_game()
	var difficulty: int = game.difficulty_level
	game.start_next_season("TPBL", true)
	check(game.difficulty_level == difficulty and game.current_league == "SBL", "rejected league switch has no difficulty side effect")
	game.gold = 0
	game.refresh_scout_board()
	check(game.gold == 0, "insufficient scout refresh funds never go negative")
	var p := unowned_player()
	game.gacha_candidates.clear()
	game.gacha_candidates.append(p)
	game.scout_points = 0
	game.claim_scout_choice(0)
	check(game.gacha_candidates.size() == 1 and not game.team_has_player(p), "unaffordable scout choice stays available")
	game.training_points = 0
	var before_ovr: int = game.team_players[0].ovr
	game.apply_player_training(0, false)
	check(game.team_players[0].ovr == before_ovr, "training cannot bypass points")
	game.training_points = 1
	game.team_players[0].ovr = 90
	game.apply_player_training(0, false)
	check(game.training_points == 1, "max OVR training does not consume points")
	await fresh_game()
	game.salary_cap = game.roster_salary()
	game.training_points = 1
	before_ovr = game.team_players[0].ovr
	var money: int = game.budget_million
	game.apply_player_training(0, false)
	check(game.team_players[0].ovr == before_ovr and game.training_points == 1 and game.budget_million == money, "over-cap training preserves player, point and money")
	game.salary_cap = 100000
	game.generate_scout_candidates()
	var first_key: String = game.player_identity_key(game.gacha_candidates[0])
	game.scout_points = 1000
	game.claim_scout_choice(0, first_key)
	var points_after: int = game.scout_points
	game.claim_scout_choice(0, first_key)
	check(game.scout_points == points_after, "stale scout confirmation cannot buy a different player")
	await fresh_game()
	game.gold = 100
	game.public_players.clear()
	game.league_teams.clear()
	game.career_rules["golden_generation"] = []
	game.refresh_scout_board()
	check(game.gold == 100, "empty scout pool does not charge refresh gold")
	await fresh_game()
	game.active_challenge = "salary_cap"
	game.apply_match_challenge(true, 10)
	check(not bool(game.challenge_completed.get("salary_cap", false)), "salary challenge cannot be completed just by spending cash")
	for player in game.team_players:
		player.salary_million = 70
	game.apply_match_challenge(true, 800)
	check(bool(game.challenge_completed.get("salary_cap", false)), "salary challenge checks actual payroll")
	await fresh_game()
	game.national_roster.clear()
	game.national_roster.append(game.team_players[0].duplicate(true))
	game.closer_name = "上一隊球員"
	game.last_box_sheet = [{"name": "上一隊球員", "pts": 99}]
	game.start_new_game()
	check(game.national_roster.is_empty() and game.closer_name.is_empty() and game.last_box_sheet.is_empty(), "new club clears old roster and box score state")

func test_slot_isolation() -> void:
	await fresh_game()
	game.card_inventory = [unowned_player()]
	game.challenge_completed = {"small_market": true}
	game.gold = 9999
	game.coach_id = "sbl_press"
	var legacy := {"club_name": "舊版第二格", "team_players": game.team_players.duplicate(true), "current_league": "SBL"}
	Store.write_save(game.slot_save_path(1), legacy)
	game.active_save_slot = 1
	game.load_game(false)
	check(game.card_inventory.is_empty(), "legacy slot does not inherit other slot inventory")
	check(game.gold != 9999 and game.coach_id == "sbl_rookie", "legacy slot resets missing money and coach fields")
	check(not bool(game.challenge_completed.get("small_market", false)), "legacy slot does not inherit achievements")
	game.extra_save_bought = 8
	game.show_save_slots()
	await process_frame
	var slots := game.find_children("SaveSlot?", "Control", true, false)
	check(slots.size() == 10, "all ten unlocked save slots are visible in the selector")
	var current_slot: int = game.active_save_slot
	game.open_save_slot(99)
	check(game.active_save_slot == current_slot, "invalid slot cannot change active save")
	var original_data: Dictionary = Store.read_save(game.slot_save_path(1))
	check(game.import_cloud_slot(1, {}) != OK, "empty cloud response cannot overwrite a save")
	check(Store.read_save(game.slot_save_path(1)) == original_data, "rejected cloud import preserves local data")
	check(game.import_cloud_slot(99, original_data) != OK, "cloud slot index is bounded")
	var remote := original_data.duplicate(true)
	remote.club_name = "雲端測試隊"
	check(game.import_cloud_slot(1, remote) == ERR_BUSY and Store.read_save(game.slot_save_path(1)) == original_data, "different cloud progress waits for explicit choice without overwriting")
	check(game.CloudSync.resolve(game,1,true), "explicit cloud import applies atomically after backup")
	var archive := Store.read_save(str(game.sync_state.slots["1"].get("last_backup","")))
	check(archive.get("local") == original_data and archive.get("remote") == remote, "cloud replacement keeps both complete generations in a durable backup")

func test_purchase_validation() -> void:
	game.show_purchase_success("測試商品", "已入帳")
	check(is_instance_valid(game.guide_modal) and game.guide_modal.name == "PurchaseSuccessModal", "successful purchases use the dedicated confirmation modal")
	game.close_guide_modal()
	game.iap_pending_sku = "extra_save"
	check(game.iap_event_matches_pending({"type": "purchase", "result": "ok", "product_id": "tb_extra_save"}), "StoreKit success uses string result and exact product")
	for event in [{}, {"type": "purchase"}, {"type": "purchase", "result": 1}, {"type": "purchase", "result": "error", "product_id": "tb_extra_save"}, {"type": "purchase", "result": "ok", "product_id": "tb_national"}]:
		check(not game.iap_event_matches_pending(event), "unmatched/failed purchase must not unlock content")
	game.iap_pending_sku = ""
	check(not game.iap_event_matches_pending({"type": "purchase", "result": "ok", "product_id": "tb_extra_save"}), "replayed event without pending purchase is ignored")
	var verifier: String = game.pkce_verifier()
	check(verifier.length() >= 43 and verifier.length() <= 128 and verifier != game.pkce_verifier(), "PKCE verifier is valid-length and fresh")
	check(game.pkce_challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", "PKCE S256 matches RFC example")

func test_draft_and_acquisition() -> void:
	await fresh_game()
	game.active_challenge = ""
	game.show_challenge_detail("small_market")
	check(game.active_challenge.is_empty() and game.find_child("GuideModal", true, false) != null, "tapping a task opens details without starting it")
	game.close_guide_modal()
	game.complete_active_challenge("small_market")
	check(game.mission_alert and game.mission_shortcut_title() == "任務！", "completed task raises a persistent exclamation alert")
	var diamond_player: Dictionary = game.stamp_prize_card({}, game.extra_prize_spec("liu"))
	check(game.is_combo_wild(diamond_player), "every diamond card counts toward any team combination for free")
	check(game.combo_step_bonus(5, "sbl_bank") == 1 and game.combo_step_bonus(7, "sbl_bank") == 2 and game.combo_step_bonus(10, "sbl_bank") == 3 and game.combo_step_bonus(12, "sbl_bank") == 4, "SBL combination steps are 1/2/3/4")
	check(game.combo_step_bonus(5, "fubon") == 2 and game.combo_step_bonus(7, "fubon") == 4 and game.combo_step_bonus(10, "fubon") == 6 and game.combo_step_bonus(12, "fubon") == 8, "PLG and TPBL combination steps are doubled")
	var diamond_card: Control = game.player_show_card(diamond_player, "", "", game.DIAMOND, false, func(): pass)
	game.add_child(diamond_card)
	await process_frame
	check(diamond_card.find_child("OriginName", true, false) == null, "diamond card omits original team name")
	check(diamond_card.find_child("OriginLogo", true, false) == null, "diamond card omits team logo and fallback mark")
	check(diamond_card.find_child("Plate", true, false) == null, "player card has no opaque rectangular backing behind transparent frame")
	diamond_card.free()
	game.ensure_season_scout()
	game.show_gacha_market()
	check(game.find_children("ScoutBuyButton", "Button", true, false).size() == game.gacha_candidates.size(), "every scout offer has its own buy button")
	game.scout_floor_game = game.season_games # Isolate price from the existing once-per-game point floor.
	game.gold = game.SCOUT_REFRESH_GOLD
	game.scout_points = 17
	game.scout_free_refresh_date = ""
	game.refresh_scout_board()
	check(game.gold == game.SCOUT_REFRESH_GOLD and game.scout_points == 17 and game.gacha_candidates.size() == 6, "first daily scout refresh is free and never spends scout points")
	var board: Array = game.gacha_candidates.duplicate(true)
	game.gold = 0
	game.refresh_scout_board()
	check(game.gold == 0 and game.scout_points == 17 and game.gacha_candidates == board, "scout points cannot replace missing refresh gold")
	game.scout_points = 50
	game.gold = 1000
	game.public_players.clear()
	game.league_teams.clear()
	game.career_rules["golden_generation"] = []
	game.refresh_scout_board()
	check(game.scout_points == 50 and game.gold == 1000, "failed scout generation charges neither currency")
	await fresh_game()
	var prospect_pool: Array = game.DraftCatalog.players()
	var names := {}
	var counts := {"PLG":0, "TPBL":0, "SBL":0}
	for p in prospect_pool:
		check(not names.has(p.name), "2026 prospect name is unique: " + str(p.name))
		names[p.name] = true
		for registration in p.registrations:
			counts[registration.league] += 1
		check(game.player_image(p).tex == null and game.official_photo_path(p).is_empty(), "rookie does not borrow a real or illustrative player's face")
		check(game.published_salary(game.to_game_player(p)) == 100, "rookie declared starting salary matches actual cap charge")
	check(prospect_pool.size() == 45 and counts == {"PLG":25, "TPBL":30, "SBL":27}, "three registration lists merge into 45 unique entrants")
	game.regular_games = game.regular_season_length()
	game.season_games = game.regular_games
	for phase in ["regular", "semifinal", "final"]:
		game.season_phase = phase
		game.draft_player(prospect_pool[0])
		check(not game.draft_eligible() and game.drafted_prospect_ids.is_empty(), "draft locked before entire season ends: " + phase)
	game.season_phase = "offseason"
	game.match_rewards_pending = true
	check(not game.draft_eligible(), "unsettled result cannot open draft")
	game.match_rewards_pending = false
	game.current_league = "EASL"
	check(not game.draft_eligible(), "three-game international event cannot award domestic draft")
	game.current_league = "SBL"
	game.reset_league_table()
	var team_index := 0
	for tid in game.league_table:
		game.league_table[tid].w = 2 if tid == game.club_team_id() else team_index * 2
		game.league_table[tid].l = 20 - int(game.league_table[tid].w)
		team_index += 1
	game.capture_draft_order()
	var snapshot: Array = game.draft_state.order.duplicate(true)
	var prev := -1.0
	for row in snapshot:
		var rate := float(row.w) / maxi(1, int(row.w) + int(row.l))
		check(rate >= prev, "draft order is worst regular-season winning percentage first")
		prev = rate
	game.league_table[game.club_team_id()].w = 99
	game.prepare_draft()
	check(game.draft_state.order == snapshot, "playoff record changes do not change draft order")
	check(game.drafted_prospect_ids.size() == int(game.draft_state.user_pick) - 1, "AI preceding picks remove exactly the prior slots")
	var taken: Array = game.drafted_prospect_ids.duplicate()
	game.prepare_draft()
	game.save_game()
	game.load_game(false)
	game.prepare_draft()
	check(game.drafted_prospect_ids == taken, "opening or reloading cannot reroll AI picks")
	game.draft_player({"id":"unregistered-player", "name":"假資料"})
	check(not game.draft_state.get("completed", false), "forged or unavailable draft candidate cannot claim a pick")
	var candidate: Dictionary = game.remaining_draft_players()[0]
	game.salary_cap = 0
	var resources := [game.gold, game.scout_points, game.budget_million]
	game.draft_player(candidate)
	check(game.inventory_has_player(candidate) and game.draft_state.completed, "over-cap draft pick goes into vault and consumes one pick")
	check([game.gold, game.scout_points, game.budget_million] == resources, "draft charges no purchase fee")
	var total_taken: int = game.drafted_prospect_ids.size()
	check(total_taken == snapshot.size(), "one round completes once for every team")
	game.draft_player(game.remaining_draft_players()[0])
	check(game.drafted_prospect_ids.size() == total_taken, "double confirmation cannot grant a second pick")
	game.save_game()
	game.load_game(false)
	check(game.draft_state.completed and game.inventory_has_player(candidate), "draft completion and rookie survive save/reload")
	game.start_next_season("SBL", false)
	check(game.draft_state.is_empty() and game.drafted_prospect_ids.size() == total_taken and not game.draft_eligible(), "next season resets eligibility but keeps career drafted players")
	check(not game.remaining_draft_players().any(func(p): return p.id == candidate.id), "previously drafted player cannot reappear next year")
	game.regular_games = game.regular_season_length()
	game.season_games = game.regular_games
	game.season_phase = "champion"
	game.start_next_season("SBL", false)
	check(game.season_phase == "champion" and is_instance_valid(game.guide_modal), "next-season action asks before discarding an unused draft")
	game.prepare_draft()
	candidate = game.remaining_draft_players()[0]
	game.card_inventory.append(candidate.duplicate(true))
	var gold_before: int = game.gold
	var vault_size: int = game.card_inventory.size()
	game.draft_player(candidate)
	await process_frame
	check(game.gold == gold_before and game.card_inventory.size() == vault_size + 1, "duplicate draft selection is retained as a card")
	check(game.find_child("DuplicateCardNotice", true, false) != null, "draft duplicate shows a small notification modal")
	await fresh_game()
	game.grant_prize_card("lin", false)
	var owned_size: int = game.team_players.size() + game.card_inventory.size()
	gold_before = game.gold
	game.grant_prize_card("lin", false)
	await process_frame
	check(game.gold == gold_before and game.team_players.size() + game.card_inventory.size() == owned_size + 1, "duplicate diamond reward is retained")
	check(game.find_child("DuplicateCardNotice", true, false) != null, "reward duplicate shows notification")
	await fresh_game()
	var owned: Dictionary = game.team_players[0].duplicate(true)
	game.gacha_candidates.assign([owned])
	game.scout_points = 1000
	gold_before = game.gold
	game.claim_scout_choice(0)
	await process_frame
	check(game.gold == gold_before and game.card_inventory.size() == 1, "duplicate scout purchase is retained exactly once")
	check(game.card_inventory.size() == 1, "scout duplicate remains available for the purchase-success flow")
	await fresh_game()
	owned = game.team_players[0].duplicate(true)
	game.public_players.assign([owned])
	gold_before = game.gold
	game.gold_scout_pull()
	await process_frame
	check(game.gold == gold_before - 80 and game.card_inventory.size() == 1, "store gold pack duplicate is retained")
	check(game.card_inventory.size() == 1, "gold pack duplicate remains available for the purchase-success flow")
	await fresh_game()
	game.pro_top2 = true
	game.easl_pass = true
	game.pick_extra_entry("easl", {})
	game.show_extra_match_prep()
	check(not game.match_rewards_pending and not game.extra_match, "extra match prep does not prematurely start or settle a game")
	check(game.find_child("MatchPrepLineups", true, false) != null, "extra match has the same two-sided lineup presentation")
	var home_bench := game.find_child("HomeBench", true, false)
	var away_bench := game.find_child("AwayBench", true, false)
	check(home_bench != null and home_bench.find_children("*", "Button", true, false).size() == mini(5, maxi(0, game.team_players.size() - 5)), "pregame shows every available home bench card up to five")
	check(away_bench != null and away_bench.find_children("*", "Button", true, false).size() > 0, "pregame shows opponent bench cards when roster data exists")
	if home_bench != null and not home_bench.find_children("*", "Button", true, false).is_empty():
		home_bench.find_children("*", "Button", true, false)[0].pressed.emit()
		await process_frame
		check(game.selected_foundation == 5, "first pregame bench card opens the matching player instead of the last loop item")
		game.show_extra_match_prep()
	check(game.current_match_opponent().team_id == game.extra_queue[0].id, "tactics adjustment retains the actual extra-match opponent")
	game.show_dashboard()
	check(game.prep_extra_event.is_empty(), "returning home clears extra context before showing the next league fixture")
	game.show_extra_match_prep()
	game.show_match_prep()
	check(game.prep_extra_event.is_empty(), "normal fixture clears the extra-match scouting context")
	await fresh_game()

func test_season_simulation() -> void:
	await fresh_game()
	for total in [0, 1, 10, 55, 90, 150, 210]:
		seed(42 + total)
		game.roll_match_rotation()
		game.generate_box_sheet(total)
		var sum := 0
		for line in game.last_box_sheet:
			sum += int(line.pts)
			check(int(line.pts) >= 0, "box score points nonnegative")
		check(sum == total, "box score totals match team points: %d != %d" % [sum, total])
	var played := 0
	for season in 3:
		if season > 0:
			game.start_next_season("SBL", true, true)
		check(game.season_phase == "regular" and game.season_games == 0, "each audited season actually starts fresh")
		for match_index in 45:
			if game.season_phase in ["champion", "offseason"]:
				break
			game.start_match()
			game.match_play_id += 1
			check(game.match_rewards_pending, "season can start match")
			if not game.match_rewards_pending:
				break
			seed(9000 + season * 100 + match_index)
			game.roll_quarters_from(0)
			game.skip_match_presentation()
			check(game.last_score[0] != game.last_score[1], "match resolves tied score")
			check(game.season_wins + game.season_losses == game.season_games, "season win/loss totals remain consistent")
			check(game.gold >= 0 and game.scout_points >= 0 and game.training_points >= 0, "resources remain nonnegative")
			var sum := 0
			for line in game.last_box_sheet:
				sum += int(line.pts)
			check(sum == game.last_score[0], "actual match player points equal final score")
			var games: int = game.season_games
			game.show_post_match()
			check(game.season_games == games, "season result cannot be claimed twice")
			played += 1
			await process_frame
		check(game.season_phase in ["champion", "offseason"], "season reaches an ending")
	print("SEASON_AUDIT seasons=3 matches=%d" % played)

func postseason_fixture(league: String, user_seed: int) -> Dictionary:
	var ranked: Array = []
	for i in 7:
		ranked.append({"team_id":"club" if i + 1 == user_seed else "audit_%d" % i, "name":"俱樂部" if i + 1 == user_seed else "測試隊%d" % i, "rating":75})
	return game.PlayoffSeries.create(league, ranked, 12345)

func test_series_and_balance() -> void:
	await fresh_game()
	for league in ["SBL", "PLG", "TPBL"]:
		var cut: int = game.PlayoffSeries.rules(league).cut
		for rank in range(1, cut + 1):
			var state := postseason_fixture(league, rank)
			var seen := {}
			for guard in 5:
				var current: Array = game.PlayoffSeries.current(state)
				for s in current:
					var user := str(s.a.team_id) == "club" or str(s.b.team_id) == "club"
					if user:
						seen[s.phase] = true
					var high_wins := str(s.a.team_id) == "club" if user else true
					while s.winner.is_empty():
						game.PlayoffSeries.record(s, 90 if high_wins else 80, 80 if high_wins else 90)
					var count: int = s.games.size()
					check(not game.PlayoffSeries.record(s, 90, 80) and s.games.size() == count, "closed series rejects a duplicate game")
				if not game.PlayoffSeries.advance(state):
					break
			check(state.champion.get("team_id") == "club", "%s seed %d can win the complete bracket" % [league, rank])
			check(seen.has("final"), "every champion plays a final series")
			if league == "PLG" and rank == 1:
				check(not seen.has("semifinal"), "PLG top seed earns a finals bye")
			if league == "TPBL" and rank >= 4:
				check(seen.has("playin"), "TPBL seed 4/5 must play in")
	var tpbl := postseason_fixture("TPBL", 4)
	var playin: Dictionary = tpbl.rounds[0][0]
	check(playin.wa == 1 and playin.wb == 0 and playin.games.is_empty(), "TPBL seed four's advantage is not a played game")
	check(not game.PlayoffSeries.high_home(playin), "TPBL first actual game is at seed five")
	game.PlayoffSeries.record(playin, 70, 80)
	check(playin.winner.is_empty() and game.PlayoffSeries.high_home(playin), "TPBL final deciding game is at seed four")
	game.PlayoffSeries.record(playin, 70, 80)
	check(playin.winner.team_id != "club", "TPBL seed four can still be eliminated")
	check(game.PlayoffSeries.rules("SBL").semi == 2 and game.PlayoffSeries.rules("SBL").final == 3, "SBL 23 is best of three then five")
	check(game.PlayoffSeries.rules("PLG").semi == 3 and game.PlayoffSeries.rules("PLG").final == 4, "PLG is best of five then seven")
	# Exercise real settlement, save/resume, and isolation from regular standings.
	game.current_league = "SBL"
	game.playoff_state = postseason_fixture("SBL", 1)
	game.advance_playoff_bracket()
	var table_before: Dictionary = game.league_table.duplicate(true)
	game.regular_games = game.regular_season_length()
	game.last_opponent = game.league_match_opponent()
	game.last_score.assign([90, 80])
	game.quarter_scores = [[22,22,23,23], [20,20,20,20]]
	game.reveal_quarter = 4
	game.match_rewards_pending = true
	game.extra_match = false
	game.show_post_match()
	check(game.season_phase == "semifinal", "one semifinal win does not advance SBL")
	check(game.league_table == table_before, "postseason never mutates regular standings")
	check(not game.draft_eligible(), "draft is unavailable during a live series")
	var bracket_before := JSON.stringify(game.playoff_state)
	var balances := [game.gold, game.scout_points, game.budget_million]
	game.show_post_match()
	check(JSON.stringify(game.playoff_state) == bracket_before and balances == [game.gold, game.scout_points, game.budget_million], "reopening result does not duplicate series wins or rewards")
	game.save_game()
	game.load_game(false)
	check(game.playoff_state == JSON.parse_string(bracket_before), "series resumes with the exact bracket and scores")
	var before_tactic: Dictionary = game.opponent_tactic(str(game.last_opponent.team_id)).duplicate(true)
	game.save_game()
	game.load_game(false)
	check(game.opponent_tactic(str(game.last_opponent.team_id)) == before_tactic, "series tactical adaptation survives reload")
	# Pending overtime is resumed from the exact saved scores; no reroll or early reward.
	game.quarter_scores = [[20,20,20,20,8,9],[20,20,20,20,8,7]]
	game.reveal_quarter = 5
	game.last_score.assign([88,88])
	game.match_rewards_pending = true
	game.save_game()
	game.load_game(false)
	check(game.match_rewards_pending and game.reveal_quarter == 5 and game.match_period_count() == 6, "multiple overtime survives an in-progress reload")
	check(game.last_score == [88,88] and game.quarter_scores[0][5] == 9, "reload keeps the saved visible and upcoming overtime scores")
	check(game.match_visible_period_count() == 6, "a tied first overtime reveals the next overtime only")
	game.reveal_quarter = 0
	game.last_score.assign([0,0])
	check(game.match_visible_period_count() == 4, "precomputed overtime never spoils regulation presentation")
	game.match_rewards_pending = false
	# Legacy qualification is retained rather than restarting the season.
	game.playoff_state.clear()
	game.season_phase = "final"
	game.ensure_legacy_playoffs()
	check(game.PlayoffSeries.user_series(game.playoff_state).phase == "final", "legacy finalist remains a finalist")
	# A genuine tied regulation score must finish in overtime and settle only once.
	game.last_opponent = game.league_match_opponent()
	game.last_score.assign([80, 80])
	game.quarter_scores = [[20,20,20,20],[20,20,20,20]]
	game.reveal_quarter = 4
	game.match_rewards_pending = true
	game.show_post_match()
	check(game.quarter_scores[0].size() > 4 and game.last_score[0] != game.last_score[1], "80-80 goes to overtime, never a tied defeat")
	check(game.last_score[0] == game._quarter_sum(0, game.quarter_scores[0].size()), "overtime totals match every period")
	# Bench skill changes must not change a first-quarter active-five profile.
	game.roll_match_rotation()
	game.reveal_quarter = 0
	var skills: Dictionary = game.team_skill_modifiers().duplicate(true)
	if game.team_players.size() > 5:
		game.team_players[5]["skill_id"] = "volume_scorer"
		check(game.team_skill_modifiers() == skills, "inactive bench scorer adds no first-quarter skill")
	var rates: Array = []
	for gap in [0, 10, -10]:
		var wins := 0
		for trial in 3000:
			var rng := RandomNumberGenerator.new()
			rng.seed = 20260831 + trial
			var score: Array = game.MatchSimulator.game({"rating":75 + gap}, {"rating":75}, rng)
			wins += int(score[0] > score[1])
			check(score[0] != score[1], "shared simulation resolves ties symmetrically")
		rates.append(wins / 3000.0)
	check(rates[0] >= 0.45 and rates[0] <= 0.55, "equal neutral profiles have near-even odds")
	check(rates[1] > rates[0] + 0.10 and rates[2] < rates[0] - 0.10, "OVR advantage is meaningful in both directions")
	print("BALANCE_V2 neutral_equal=%.3f stronger10=%.3f weaker10=%.3f n=9000" % [rates[0], rates[1], rates[2]])

func open_playoffs_for_layout() -> void:
	game.extra_match = false
	game.current_league = "TPBL"
	game.playoff_state = postseason_fixture("TPBL", 4)
	game.advance_playoff_bracket()
	game.show_match_prep()
	game.show_playoff_bracket()

func open_overtime_for_layout() -> void:
	game.close_guide_modal()
	game.last_opponent = game.league_match_opponent()
	game.quarter_scores = [[20,20,20,20,8,7,9],[20,20,20,20,8,7,6]]
	game.quarter_stories = ["Q1", "Q2", "Q3", "Q4", "OT1", "OT2", "OT3"]
	game.reveal_quarter = 6
	game.last_score.assign([95,95])
	game.roll_match_rotation()
	game.match_rewards_pending = false
	game.show_match_presentation()

func open_draft_for_layout() -> void:
	game.regular_games = game.regular_season_length()
	game.season_games = game.regular_games
	game.season_phase = "offseason"
	game.draft_state.clear()
	game.drafted_prospect_ids.clear()
	game.show_draft_market()

func open_draft_confirmation() -> void:
	var content := game.find_child("Content", true, false)
	var options := content.find_children("*", "Button", true, false)
	options[2].pressed.emit()

func open_extra_prep_for_layout() -> void:
	game.pro_top2 = true
	game.easl_pass = true
	game.pick_extra_entry("easl", {})
	game.show_extra_match_prep()

func open_free_agent_for_layout() -> void:
	var player: Dictionary = game.cheap_bench_player()
	game.show_player_sheet(player, game.show_free_agent_market, func(): game.sign_free_agent(player), "確認自由簽約", -1, true)

func open_tier_up_for_layout() -> void:
	var player: Dictionary = game.to_game_player({"name":"升框測試球員", "position":"SG", "ovr":71, "origin_team_id":"sbl_yulon"})
	player["training_sessions"] = 1
	player["salary_million"] = game.published_salary(player)
	game.show_tier_up_reveal(player, "cyan", 70)

func extended_visual_tour() -> void:
	await fresh_game()
	var output := OS.get_environment("TB_TEST_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	var sizes := [Vector2i(568, 320), Vector2i(844, 390), Vector2i(740, 740)]
	if not OS.get_environment("TB_TEST_SIZES").is_empty():
		sizes.clear()
		for raw in OS.get_environment("TB_TEST_SIZES").split(","):
			var xy := raw.split("x")
			sizes.append(Vector2i(int(xy[0]), int(xy[1])))
	for spec in sizes:
		root.min_size = Vector2i(568, 320)
		root.size = spec
		await process_frame
		for entry in [
			["saves", func(): game.extra_save_bought = 8; game.show_save_slots()],
			["home", func(): game.home_environment_mode = "arena"; game.show_dashboard()],
			["home_more", func(): game.show_dashboard(); game.show_dashboard_more_menu()],
			["home_locker", func(): game.home_environment_mode = "locker"; game.show_dashboard()],
			["store", func(): game.select_store_product("精選", "arena_taipei")],
			["store_arenas", func(): game.select_store_product("球場", "arena_taipei")],
			["store_lockers", func(): game.select_store_product("更衣室", "locker_wood")],
			["store_utilities", func(): game.select_store_product("便利功能", "vault_plus_10")],
			["store_events", func(): game.select_store_product("賽事", "event_jones")],
			["store_gold", func(): game.select_store_product("黃金", "monthly_pass")],
			["welcome", game.show_welcome_back], ["build", game.show_team_build],
			["logos", game.show_club_logo_picker], ["settings", game.show_settings_hub],
			["legal", func(): game.show_settings_hub(); game.show_legal_notice()],
			["data", game.show_data_center], ["league", game.show_league_overview],
			["team", func(): game.show_team_profile(game.league_teams[0])],
			["free_agents", game.show_free_agent_market], ["draft", game.show_draft_market],
			["free_agent_confirm", open_free_agent_for_layout],
			["finance", game.show_finance_sheet],
			["market", game.show_trade_market], ["vault", func(): game.card_inventory = [unowned_player()]; game.show_card_vault()],
			["supporters", game.show_supporter_club], ["challenges", game.show_challenge_hub],
			["news", game.show_news_center], ["national", game.show_national_team],
			["guide", game.show_game_guide], ["extra", game.show_extra_events],
			["extra_detail", func(): game.show_extra_event("jones")],
			["combo", game.show_combo_overview], ["tactics", game.show_tactics],
			["coach", game.show_coach_market], ["offseason", game.show_offseason],
			["salary", func(): game.show_dashboard(); game.show_salary_sheet()],
			["referral", func(): game.show_dashboard(); game.show_referral_sheet()],
			["iap", func(): game.show_iap_sheet("extra_save")],
			["card_reveal", func(): game.show_dashboard(); game.show_card_reveal(game.team_players[0])],
			["tier_up", open_tier_up_for_layout],
			["share", func(): game.show_dashboard(); game.show_share_sheet("測試分享", game.team_players[0])],
			["market_hub", game.show_market],
			["draft_open", open_draft_for_layout],
			["draft_confirm", open_draft_confirmation],
			["draft_order", game.show_draft_order],
			["draft_skip", func(): game.start_next_season("SBL", false)],
			["duplicate", func(): game.show_market(); game.apply_duplicate_convert(game.team_players[0])],
			["extra_prep", open_extra_prep_for_layout],
			["playoff_bracket", open_playoffs_for_layout],
			["overtime", open_overtime_for_layout],
		]:
			entry[1].call()
			game.match_play_id += 1
			await create_timer(0.75 if entry[0] in ["card_reveal", "tier_up"] else 0.15).timeout
			if OS.get_environment("TB_TEST_VISUAL") == "1":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("%dx%d_full_%s.png" % [spec.x, spec.y, entry[0]]))
			for button in game.find_children("*", "Button", true, false):
				if not button.is_visible_in_tree(): continue
				check(button.has_meta("premium_skin"), "extended screen button receives shared skin: " + str(entry[0]))
				if not button.text.is_empty():
					check(button.size.x >= 40, "text button must not collapse: %s / %s" % [entry[0], button.text])
				var ancestor := button.get_parent()
				var in_scroll := false
				while ancestor != null and ancestor != game:
					if ancestor is ScrollContainer: in_scroll = true; break
					ancestor = ancestor.get_parent()
				if not in_scroll:
					check(game.get_viewport_rect().grow(1).encloses(button.get_global_rect()), "full screen fixed button fits %s %s: %s %s" % [entry[0], spec, button.text, button.get_global_rect()])
			for card in game.find_children("*", "Button", true, false):
				if card.has_meta("player_card"): check_card_layout(card)
		game.start_next_season("SBL", false, true)
