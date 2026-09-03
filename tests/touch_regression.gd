extends "res://tests/mobile_regression.gd"

func emit_touch(point: Vector2, pressed: bool, index := 0) -> void:
	var event := InputEventScreenTouch.new()
	event.window_id = root.get_window_id()
	event.index = index
	event.position = root.get_final_transform() * point
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func emit_drag(point: Vector2, relative: Vector2, index := 0) -> void:
	var event := InputEventScreenDrag.new()
	event.window_id = root.get_window_id()
	event.index = index
	event.position = root.get_final_transform() * point
	event.relative = root.get_final_transform().basis_xform(relative)
	event.velocity = event.relative * 60.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func swipe(start: Vector2, delta: Vector2) -> void:
	emit_touch(start, true)
	await process_frame
	for step in range(1, 13):
		emit_drag(start + delta * float(step) / 12.0, delta / 12.0)
		await create_timer(0.016).timeout
	emit_touch(start + delta, false)
	await create_timer(0.15).timeout

func tap(point: Vector2) -> void:
	emit_touch(point, true)
	await create_timer(0.03).timeout
	emit_touch(point, false)
	await create_timer(0.05).timeout

func settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.08).timeout

func save_shot(name: String) -> void:
	if OS.get_environment("TB_TEST_VISUAL") != "1":
		return
	var output := OS.get_environment("TB_TEST_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("%dx%d_%s.png" % [root.size.x, root.size.y, name]))

func test_vertical_pages() -> void:
	for entry in [["result", game.show_post_match], ["market", game.show_free_agent_market], ["salary", game.show_salary_sheet], ["guide", game.show_game_guide], ["tactics", game.show_tactics], ["coach", game.show_coach_market], ["vault", func():
		game.card_inventory.assign(game.scout_player_pool().slice(0, 24))
		game.show_card_vault()
	]]:
		entry[1].call()
		await settle()
		if entry[0] == "result":
			var details: Control = game.find_child("ResultDetails", true, false)
			check(not details.visible, "phone result starts with only essential information")
			await save_shot("result_summary")
			var toggle: Button = game.find_child("ResultDetailsToggle", true, false)
			var summary_scroll: ScrollContainer = game.find_child("ContentScroll", true, false)
			# Small screens can still scroll to the analysis control.
			for attempt in 3:
				if summary_scroll.get_global_rect().encloses(toggle.get_global_rect()):
					break
				await swipe(summary_scroll.get_global_rect().get_center(), Vector2(0, -140))
			await create_timer(0.6).timeout
			await tap(toggle.get_global_rect().get_center())
			await settle()
			check(is_instance_valid(details) and details.visible, "touch tap reveals full match analysis")
			if not is_instance_valid(details):
				continue
		var scroll := game.find_child("ContentScroll", true, false) as ScrollContainer
		var scroll_id := scroll.get_instance_id()
		var overflow := scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page
		var rect := scroll.get_global_rect()
		await swipe(rect.position + rect.size * Vector2(0.65, 0.75), Vector2(0, -150))
		var current := game.find_child("ContentScroll", true, false) as ScrollContainer
		check(is_instance_valid(scroll) and current.get_instance_id() == scroll_id, "swipe never activates an underlying card/action: " + entry[0])
		if not is_instance_valid(scroll):
			continue
		print("TOUCH_SCROLL ", entry[0], "=", scroll.scroll_vertical)
		check(scroll.scroll_vertical > minf(30, overflow * 0.5) if overflow > 0 else scroll.scroll_vertical == 0, "finger scroll respects content bounds: " + entry[0])
		if entry[0] == "result":
			await save_shot("result_after_swipe")
			for i in 8:
				await swipe(rect.position + rect.size * Vector2(0.65, 0.75), Vector2(0, -180))
			var bar := scroll.get_v_scroll_bar()
			check(absf(scroll.scroll_vertical - (bar.max_value - bar.page)) <= 2, "result can reach its bottom by touch only")
			await save_shot("result_bottom")

func test_buttons_and_nested_scrollers() -> void:
	var content: VBoxContainer = game.begin_screen("觸控互動驗證", "拖曳不觸發操作", 4)
	var clicks := [0]
	for i in 12:
		content.add_child(game.action_button("測試按鈕 %d" % i, game.GOLD, func(): clicks[0] += 1))
	await settle()
	var scroll := game.find_child("ContentScroll", true, false) as ScrollContainer
	var first: Button = content.get_child(0)
	await swipe(first.get_global_rect().get_center(), Vector2(0, -140))
	check(scroll.scroll_vertical > 30 and clicks[0] == 0, "dragging a button scrolls, with zero action calls")
	# Let native inertia stop before testing a stationary tap.
	await create_timer(0.8).timeout
	scroll.scroll_vertical = 0
	await settle()
	await tap(first.get_global_rect().get_center())
	check(clicks[0] == 1, "a normal touch tap still activates exactly once")
	await tap(first.get_global_rect().get_center())
	check(clicks[0] == 2, "button remains usable after a cancelled drag")
	var old_roster: Array = game.team_players.duplicate(true)
	while game.team_players.size() < 12:
		game.team_players.append(game.cheap_bench_player())
	game.roster_filters_visible = false
	game.roster_filter_pos = ""
	game.roster_filter_origin = ""
	game.roster_filter_ovr = 0
	game.show_roster(true)
	await settle()
	var before_roster: Array = game.team_players.duplicate(true)
	var outer := game.find_child("ContentScroll", true, false) as ScrollContainer
	var origin_pick: int = game.swap_pick
	var board := game.find_child("PhoneRosterBoard", true, false) as Control
	check(is_instance_valid(board) and game.find_child("BenchScroll", true, false) == null, "complete starters and bench use one page without a nested horizontal scroller")
	check(game.team_players == before_roster and game.swap_pick == origin_pick, "rendering the complete bench never swaps or selects a player")
	await save_shot("bench_all_visible")
	# Filters may make the page taller; its single outer scroller must remain touchable.
	game.roster_filters_visible = true
	game.show_roster(true)
	await settle()
	outer = game.find_child("ContentScroll", true, false)
	board = game.find_child("PhoneRosterBoard", true, false)
	var visible := board.get_global_rect().intersection(outer.get_global_rect()) if is_instance_valid(board) else outer.get_global_rect()
	if visible.size.y > 20:
		var outer_overflow := outer.get_v_scroll_bar().max_value - outer.get_v_scroll_bar().page
		await swipe(visible.get_center(), Vector2(0, -130))
		check(outer.scroll_vertical > 20 if outer_overflow > 20 else outer.scroll_vertical == 0, "single roster page scrolls vertically only when filters create overflow")
	game.roster_filters_visible = false
	game.team_players.assign(old_roster)

func test_dashboard_schedule_swipe() -> void:
	game.show_dashboard()
	await settle()
	var schedule := game.find_child("HomeScheduleCarousel", true, false) as Control
	check(schedule != null, "dashboard schedule carousel exists for touch")
	if schedule == null:
		return
	var start := schedule.get_global_rect().get_center()
	var before: int = int(game.home_schedule_preview_offset)
	await swipe(start, Vector2(-110, 0))
	check(game.home_schedule_preview_offset == posmod(before + 1, game.season_schedule.size()), "left finger swipe advances one schedule card")
	schedule = game.find_child("HomeScheduleCarousel", true, false)
	await swipe(schedule.get_global_rect().get_center(), Vector2(110, 0))
	check(game.home_schedule_preview_offset == before, "right finger swipe returns one schedule card")

func test_modal_isolation() -> void:
	game.show_salary_sheet()
	await settle()
	var background := game.find_child("ContentScroll", true, false) as ScrollContainer
	game.show_guide_sheet("手指捲動說明", "這是可捲動的說明文字；拖曳時不可穿透到背後頁面。\n".repeat(60))
	await settle()
	var modal: Control = game.guide_modal
	var scroll := modal.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	await swipe(scroll.get_global_rect().get_center(), Vector2(0, -130))
	check(scroll.scroll_vertical > 30, "guide modal scrolls with touch")
	check(background.scroll_vertical == 0, "modal drag cannot move background")
	await swipe(Vector2(30, 330), Vector2(0, -120))
	check(background.scroll_vertical == 0 and game.guide_modal == modal, "outside-modal drag neither scrolls background nor dismisses it")
	game.close_guide_modal()
	await settle()
	game.training_points = 10
	game.budget_million = 1000
	game.show_training_modal()
	await settle()
	modal = game.training_modal
	scroll = modal.find_children("*", "ScrollContainer", true, false)[0]
	var before := [game.training_points, game.budget_million]
	var train: Button
	for node in scroll.find_children("*", "Button", true, false):
		if node.text == "訓練" and scroll.get_global_rect().intersection(node.get_global_rect()).size.y >= 30:
			train = node
			break
	check(train != null, "training button is available as drag origin")
	if train != null:
		var point := scroll.get_global_rect().intersection(train.get_global_rect()).get_center()
		await swipe(point, Vector2(0, -130))
		check(scroll.scroll_vertical > 20, "training list scrolls from its action button")
		check(before == [game.training_points, game.budget_million], "training drag spends no points or money")
	game.close_training_modal()

func test_draft_touch() -> void:
	game.regular_games = game.regular_season_length()
	game.season_games = game.regular_games
	game.season_phase = "offseason"
	game.draft_state.clear()
	game.drafted_prospect_ids.clear()
	game.show_draft_market()
	await settle()
	var scroll := game.find_child("ContentScroll", true, false) as ScrollContainer
	var rect := scroll.get_global_rect()
	var taken: Array = game.drafted_prospect_ids.duplicate()
	await swipe(rect.position + rect.size * Vector2(0.65, 0.8), Vector2(0, -150))
	check(scroll.scroll_vertical > 30, "2026 draft list scrolls by finger")
	check(game.drafted_prospect_ids == taken and not is_instance_valid(game.guide_modal), "dragging rookie options cannot select or confirm a pick")
	await create_timer(0.8).timeout
	scroll.scroll_vertical = 0
	await settle()
	var buttons := game.find_child("Content", true, false).find_children("*", "Button", true, false)
	await tap(buttons[2].get_global_rect().get_center())
	check(is_instance_valid(game.guide_modal) and not game.draft_state.get("completed", false), "rookie tap opens confirmation without spending the season pick")
	game.close_guide_modal()

func test_sync_choice_touch() -> void:
	game.cancel_cloud_requests()
	game.match_rewards_pending = false
	game._cloud_dirty = false
	game._cloud_account_dirty = false
	show_sync_fixture()
	await settle()
	check(is_instance_valid(game.guide_modal),"delayed training close cannot dismiss a newer sync modal")
	if not is_instance_valid(game.guide_modal):
		clear_sync_fixture()
		return
	var actions: Control = game.guide_modal.find_child("SyncChoiceActions",true,false)
	check(actions != null and game.get_viewport_rect().encloses(actions.get_global_rect()),"both sync choices remain visible without scrolling")
	var original_wallet := [game.budget_million,game.gold,game.scout_points]
	var before := Store.read_save(game.slot_save_path(9))
	await tap(actions.get_child(1).get_global_rect().get_center())
	await settle()
	check(Store.read_save(game.slot_save_path(9)) == before,"first touch only asks for confirmation, never replaces save")
	var confirm: Button
	for button in game.guide_modal.find_children("*","Button",true,false):
		if button.text == "確認使用這份":
			confirm = button
	check(confirm != null,"touch opens explicit save-choice confirmation")
	if confirm != null:
		await tap(confirm.get_global_rect().get_center())
		await settle()
		check(Store.read_save(game.slot_save_path(9)).gold == 150 and game.CloudSync.conflicts(game).is_empty(),"confirmed touch applies selected cloud snapshot exactly once")
	check(original_wallet == [game.budget_million,game.gold,game.scout_points],"choosing another slot does not merge money into active club")
	clear_sync_fixture()

func run() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("TB-Mobile-Test-"):
		quit(2)
		return
	game = TestGame.new()
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size = Vector2i(844, 390)
	await settle()
	print("TOUCH_AVAILABLE=", DisplayServer.is_touchscreen_available(), " EMULATE_MOUSE=", Input.emulate_mouse_from_touch)
	check(DisplayServer.is_touchscreen_available(), "test runtime has touch capability enabled")
	game.show_dashboard()
	await settle()
	await test_dashboard_schedule_swipe()
	var nav := game.find_child("BottomNavigation", true, false)
	var tabs := nav.find_children("*", "Button", true, false)
	await tap(tabs[2].get_global_rect().get_center())
	check(game.active_menu == "match", "match is the third touch navigation destination")
	nav = game.find_child("BottomNavigation", true, false)
	tabs = nav.find_children("*", "Button", true, false)
	await tap(tabs[3].get_global_rect().get_center())
	check(game.active_menu == "store", "fourth touch tab opens store")
	game.show_dashboard()
	await settle()
	nav = game.find_child("BottomNavigation", true, false)
	tabs = nav.find_children("*", "Button", true, false)
	await tap(tabs[4].get_global_rect().get_center())
	check(game.active_menu == "more", "fifth touch tab opens more")
	game.show_dashboard()
	game.start_match()
	game.match_play_id += 1
	game.skip_match_presentation()
	game.last_tactic_report = "對手沉退聯防（攻電梯門戰術）→剋區域／二三區域；怕全場壓迫。".repeat(4)
	var sizes := [Vector2i(568, 320), Vector2i(844, 390), Vector2i(915, 412)]
	for size in sizes:
		root.size = size
		await settle()
		await test_vertical_pages()
		await test_buttons_and_nested_scrollers()
		await test_draft_touch()
		await test_modal_isolation()
		await test_sync_choice_touch()
	game.queue_free()
	await process_frame
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) == 0, "touch tests leave no orphan nodes")
	print("TEST_USER_DIR=" + OS.get_user_data_dir())
	print("TOUCH_TEST_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
